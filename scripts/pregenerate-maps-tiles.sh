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
TILELIST_PATH=${TEGOLA_TILELIST_DIR:-$TMP_DIR}/tilelist.txt
BATCH_SIZE=${TEGOLA_PREGENERATION_BATCH_SIZE:-100}
DEQUEUE_TIMEOUT=${TEGOLA_PREGENERATION_DEQUEUE_TIMEOUT:-60}
CACHE_OPERATION=${TEGOLA_CACHE_OPERATION:-"seed"}
ENVOY_ADMIN_ENDPOINT=${ENVOY_ADMIN_ENDPOINT:-"127.0.0.1:1666"}

set -xv

exit_envoy() {
    echo "Exit envoy pod"
    curl -X POST "$ENVOY_ADMIN_ENDPOINT"/quitquitquit
}

trap exit_envoy EXIT

while true;
do
    # Dequeue a batch of messages from the queue and store them in tilelist
    echo "Dequeueing expired tiles from broker"
    poppy --broker-url "$TEGOLA_BROKER_URL" \
          --queue-name "$TEGOLA_QUEUE_NAME" \
          dequeue --batch "$BATCH_SIZE" \
                  --blocking-dequeue-timeout "$DEQUEUE_TIMEOUT" \
                  --exit-on-empty true \
                  --dequeue-raise-on-empty true | jq -r 'select(.meta.domain != "canary").tile' > "$TILELIST_PATH"

    dequeueStatus=${PIPESTATUS[0]}

    # Pregenerate tiles that exist in tilelist
    set -e
    $TEGOLA_PATH --config "$TEGOLA_CONFIG_PATH" cache $CACHE_OPERATION tile-list "$TILELIST_PATH"
    set +e

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

set +xv
