SHELL=/usr/bin/env bash -o pipefail

all: lint test build
.PHONY: all

build:
	go build ./cmd/...
.PHONY: build

install:
	go install ./cmd/...
.PHONY: install

test:
	go test -race ./...
.PHONY: test

update-vendor:
	docker run --rm \
		--user=$$UID \
		-v $$(go env GOCACHE):/.cache \
		-v $$PWD:/go/src/github.com/openshift/ci-tools \
		-w /go/src/github.com/openshift/ci-tools \
		-e GO111MODULE=on \
		-e GOPROXY=https://proxy.golang.org \
		golang:1.13 \
		/bin/bash -c "go mod tidy && go mod vendor"
.PHONY: update-vendor

validate-vendor:
	go version
	GO111MODULE=on GOPROXY=https://proxy.golang.org go mod tidy
	GO111MODULE=on GOPROXY=https://proxy.golang.org go mod vendor
	git status -s ./vendor/ go.mod go.sum
	test -z "$$(git status -s ./vendor/ go.mod go.sum | grep -v vendor/modules.txt)"
.PHONY: validate-vendor

lint:
	gofmt -s -l $(shell go list -f '{{ .Dir }}' ./... ) | grep ".*\.go"; if [ "$$?" = "0" ]; then gofmt -s -d $(shell go list -f '{{ .Dir }}' ./... ); exit 1; fi
	go vet ./...
.PHONY: lint

format:
	gofmt -s -w $(shell go list -f '{{ .Dir }}' ./... )
.PHONY: format

integration: integration-prowgen integration-pj-rehearse integration-ci-operator integration-ci-operator-configresolver integration-secret-wrapper integration-testgrid-generator integration-repo-init integration-group-auto-updater integration-ci-op-configs-mirror integration-cvp-trigger
.PHONY: integration

integration-prowgen:
	test/prowgen-integration/run.sh
	test/prowgen-integration/run.sh subdir
.PHONY: integration-prowgen

integration-pj-rehearse:
	test/pj-rehearse-integration/run.sh
.PHONY: integration-pj-rehearse

integration-ci-operator:
	test/ci-operator-integration/base/run.sh
	test/ci-operator-integration/multi-stage/run.sh
.PHONY: integration-ci-operator

integration-ci-operator-configresolver:
	test/ci-operator-configresolver-integration/run.sh
.PHONY: integration-ci-operator-configresolver

integration-secret-wrapper:
	test/secret-wrapper-integration.sh
.PHONY: integration-secret-wrapper

integration-testgrid-generator:
	test/testgrid-config-generator/run.sh
.PHONY: integration-testgrid-generator

integration-repo-init:
	test/repo-init-integration/run.sh
.PHONY: integration-repo-init

integration-repo-init-update:
	UPDATE=true test/repo-init-integration/run.sh
.PHONY: integration-repo-init-update

check-breaking-changes:
	test/validate-prowgen-breaking-changes.sh
.PHONY: check-breaking-changes

integration-group-auto-updater:
	test/group-auto-updater-integration/run.sh
.PHONY: integration-group-auto-updater

integration-ci-op-configs-mirror:
	test/ci-op-configs-mirror-integration/run.sh
.PHONY: integration-ci-op-configs-mirror

integration-cvp-trigger:
	test/cvp-trigger-integration/run.sh
.PHONY: integration-cvp-trigger

update-integration-cvp-trigger:
	test/cvp-trigger-integration/run.sh --update
.PHONY: integration-cvp-trigger


pr-deploy:
	oc process -p USER=$(USER) -p BRANCH=$(BRANCH) -p PULL_REQUEST=$(PULL_REQUEST) -f hack/pr-deploy.yaml | oc apply -f - --as system:admin
	for cm in ci-operator-configs step-registry config; do oc get --export configmap $${cm} -n ci -o json | oc apply -f - -n ci-tools-$(PULL_REQUEST) --as system:admin; done
.PHONY: pr-deploy
