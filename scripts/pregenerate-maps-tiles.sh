#!/bin/bash

if [ -z "$TEGOLA_BROKER_URL" ]
then
    echo "TEGOLA_BROKER_URL env var is not set"
    exit 1
fi

if [ -z "$TEGOLA_QUEUE_NAME" ]
then
    echo "TEGOLA_QUEUE_NAME env var is not set"
    exit 1
fi

if [ -z "$TEGOLA_PATH" ]
then
    echo "TEGOLA_PATH env var is not set"
    exit 1
fi

if [ -z "$TEGOLA_CONFIG_PATH" ]
then
    echo "TEGOLA_CONFIG_PATH env var is not set"
    exit 1
fi

TMP_DIR=$(mktemp -d /tmp/tegola-XXXXXXXXXX)
BATCH_SIZE=${TEGOLA_PREGENERATION_BATCH_SIZE:-1000}
TILELIST_PATH=${TEGOLA_TILELIST_DIR:-$TMP_DIR}/tilelist.txt
DEQUEUE_TIMEOUT=${TEGOLA_PREGENERATION_DEQUEUE_TIMEOUT:-60}
CACHE_OPERATION=${TEGOLA_CACHE_OPERATION:-"seed"}
ENVOY_ADMIN_ENDPOINT=${ENVOY_ADMIN_ENDPOINT:-"127.0.0.1:1666"}
ENVOY_HEALTHCHECK_ENDPOINT=${ENVOY_HEALTHCHECK_ENDPOINT:-"127.0.0.1:9361/healthz"}
ENVOY_HEALTHCHECK_MAX_RETRIES=${ENVOY_HEALTHCHECK_MAX_RETRIES:-5}

exit_envoy() {
    echo "Exit envoy container"
    curl -sS -X POST "$ENVOY_ADMIN_ENDPOINT"/quitquitquit
}

trap exit_envoy EXIT

# Wait for envoy sidecar to get ready
while [ "$(curl -m 5 -s -o /dev/null -w '%{http_code}' $ENVOY_HEALTHCHECK_ENDPOINT)" != "200" ]; do
    sleep 5
    ((ENVOY_HEALTHCHECK_MAX_RETRIES--))
    if [ "$ENVOY_HEALTHCHECK_MAX_RETRIES" -le 0 ]; then
        echo "Envoy not ready"
        exit 1
    fi
    echo "Retrying envoy healthcheck"
done

while true;
do
    # Dequeue a batch of messages from the queue and store tiles in tilelist
    echo "Dequeueing expired tiles from broker"
    poppy --broker-url "$TEGOLA_BROKER_URL" \
          --queue-name "$TEGOLA_QUEUE_NAME" \
          dequeue --blocking-dequeue-timeout "$DEQUEUE_TIMEOUT" \
                  --batch "$BATCH_SIZE" \
                  --exit-on-empty true \
                  --dequeue-raise-on-empty true | jq -r 'select(.meta.domain != "canary").changes | .[].tile' > "$TILELIST_PATH"

    dequeueStatus=${PIPESTATUS[0]}

    # Pregenerate tiles that exist in tilelist
    $TEGOLA_PATH --logger zap --config "$TEGOLA_CONFIG_PATH" cache $CACHE_OPERATION --overwrite tile-list "$TILELIST_PATH"

    if [ "$dequeueStatus" -eq 100 ]  # Queue is empty
    then
        echo "Reached end of queue"
        exit 0
    elif [ "$dequeueStatus" -gt 0 ]  # Something went wrong
    then
        echo "Something went wrong"
        exit 1
    fi
done
