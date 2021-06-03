TEGOLA_HASH = $(shell git rev-parse --short HEAD)
TEGOLA_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
VERSION_TAG = wmfrelease_branch_${TEGOLA_BRANCH}_hash_${TEGOLA_HASH}
LDFLAGS_VERSION = -X github.com/go-spatial/tegola/internal/build.Version=${VERSION_TAG}
LDFLAGS_BRANCH = -X github.com/go-spatial/tegola/internal/build.GitBranch=${TEGOLA_BRANCH}
LDFLAGS_REVISION = -X github.com/go-spatial/tegola/internal/build.GitRevision=${TEGOLA_HASH}
LDFLAGS = -w -s ${LDFLAGS_VERSION} ${LDFLAGS_BRANCH} ${LDFLAGS_REVISION}

dockerfile: .pipeline/blubber.yaml
	blubber .pipeline/blubber.yaml development > Dockerfile

docker: dockerfile
	docker build -t tegola  .
	docker run tegola

tegola_cmd:
	cd cmd/tegola; 	GOOS=linux go build -mod vendor -tags "noAzblobCache noGpkgProvider" -ldflags="${LDFLAGS}" -o "tegola" -v

test:
	go test
