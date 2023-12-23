NAME:=sysperf
TAG:=0.1
IMAGE:=${NAME}:${TAG}

.PHONY: build run exec debugfs
build:
	docker build -t ${IMAGE} .

run:
	@# https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json
	docker run --name ${NAME} --rm -it \
  --privileged \
  -v debugfs:/sys/kernel/debug:rw \
  -v /lib/modules:/lib/modules:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --ipc=host \
  --net=host \
  --pid=host \
  --security-opt seccomp=profile.json \
  ${IMAGE} /bin/bash

exec:
	docker exec -it $$(docker ps --filter "name=${NAME}" -q) /bin/bash

