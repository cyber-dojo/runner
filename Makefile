
SHORT_SHA := $(shell git rev-parse HEAD | head -c7)
IMAGE_NAME := cyberdojo/runner:${SHORT_SHA}

image_server:
	${PWD}/bin/build_image.sh server

test_server:
	${PWD}/bin/run_tests.sh server

coverage_server:
	${PWD}/bin/check_coverage.sh server



integration_test: image
	${PWD}/bin/test.sh client


rubocop_lint:
	docker run --rm --volume "${PWD}:/app" cyberdojo/rubocop --raise-cop-error

demo:
	${PWD}/bin/demo.sh

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

