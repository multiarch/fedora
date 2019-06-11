CWD = $(shell pwd)

.PHONY: update
update:
	./update.sh -a "$(ARCH)" -v "$(VERSION)" -q "$(QEMU_ARCH)" -u "$(QEMU_VER)" -d "$(DOCKER_REPO)"

.PHONY: test
test:
	docker run -t --rm -v "$(CWD):/work" -w /work "$(DOCKER_REPO):$(VERSION)-$(ARCH)" ./test.sh
