NAME:=sysperf
TAG:=0.1
IMAGE:=${NAME}:${TAG}

.PHONY: build run exec debugfs
build:
	docker build -t ${IMAGE} .

debugfs:
	@# https://hemslo.io/run-ebpf-programs-in-docker-using-docker-bpf/
	docker volume create --driver local --opt type=debugfs --opt device=debugfs debugfs

run:
	@# https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json
	docker run --name ${NAME} --rm -it \
  --privileged \
  -v debugfs:/sys/kernel/debug:ro \
  -v /lib/modules:/lib/modules:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --ipc=host \
  --net=host \
  --pid=host \
  --security-opt seccomp=profile.json \
  ${IMAGE} /bin/bash

exec:
	docker exec -it $$(docker ps --filter "name=${NAME}" -q) /bin/bash

