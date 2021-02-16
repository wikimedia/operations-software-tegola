dockerfile: .pipeline/blubber.yaml
	blubber .pipeline/blubber.yaml development > Dockerfile

docker: dockerfile
	docker build -t tegola  .
	docker run tegola

tegola_cmd:
	cd cmd/tegola; 	CGO_ENABLED=0 GOOS=linux go build -mod vendor -tags "noAzblobCache noGpkgProvider" -ldflags="-w -s" -v

test:
	go test
