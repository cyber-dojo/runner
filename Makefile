
SHORT_SHA := $(shell git rev-parse HEAD | head -c7)
IMAGE_NAME := cyberdojo/runner:${SHORT_SHA}

.PHONY: image lint unit_test integration_test test demo snyk-container snyk-code

image:
	${PWD}/sh/build_tag.sh

unit_test: image
	${PWD}/sh/test.sh server

integration_test: image
	${PWD}/sh/test.sh client

test: unit_test integration_test

rubocop_lint:
	docker run --rm --volume "${PWD}:/app" cyberdojo/rubocop --raise-cop-error

demo:
	${PWD}/sh/demo.sh

snyk-container: image
	snyk container test ${IMAGE_NAME} \
        --file=Dockerfile \
		--sarif \
		--sarif-file-output=snyk.container.scan.json \
        --policy-path=.snyk

snyk-code:
	snyk code test \
		--sarif \
		--sarif-file-output=snyk.code.scan.json \
        --policy-path=.snyk

