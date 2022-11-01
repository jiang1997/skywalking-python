# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION ?= next

# determine host platform
ifeq ($(OS),Windows_NT)
    detected_OS := Windows
else
    detected_OS := $(shell sh -c 'uname 2>/dev/null || echo Unknown')
endif

.PHONY: poetry env license setup test clean

poetry:
ifeq ($(detected_OS),Windows)
	-powershell (Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | py -
	poetry self update
else
	-curl -sSL https://install.python-poetry.org | python3 -
	poetry self update
endif

env: poetry
	poetry install
	poetry run pip install --upgrade pip

setup: env
	poetry run pip install grpcio --ignore-installed

setup-test: setup gen
	poetry run pip install -e .[test]

gen:
	poetry run grpc_tools.protoc --version || poetry run pip install grpcio-tools
	poetry run python tools/codegen.py

# flake8 configurations should go to the file setup.cfg
lint: clean
	poetry run flake8 .

# used in development
dev-setup:
	poetry run pip install -r requirements-style.txt

dev-check: dev-setup
	poetry run flake8 .

# fix problems described in CodingStyle.md - verify outcome with extra care
dev-fix: dev-setup
	poetry run isort .
	poetry run unify -r --in-place .
	poetry run flynt -tc -v .

doc-gen: $(VENV) install
	poetry run python tools/doc/plugin_doc_gen.py

check-doc-gen: dev-setup doc-gen
	@if [ ! -z "`git status -s`" ]; then \
		echo "Plugin doc is not consisitent with CI:"; \
		git status -s; \
		exit 1; \
	fi

license: clean
	docker run -it --rm -v $(shell pwd):/github/workspace ghcr.io/apache/skywalking-eyes/license-eye:f461a46e74e5fa22e9f9599a355ab4f0ac265469 header check

test: gen setup-test
	poetry run python -m pytest -v tests

# This is intended for GitHub CI only
test-parallel-setup: gen setup-test

install: gen
	poetry run python setup.py install --force

package: clean gen
	poetry run python setup.py sdist bdist_wheel

upload-test: package
	poetry run twine upload --repository-url https://test.pypi.org/legacy/ dist/*

upload: package
	poetry run twine upload dist/*

build-image:
	$(MAKE) -C docker build

push-image:
	$(MAKE) -C docker push

clean:
	rm -rf skywalking/protocol
	rm -rf apache_skywalking.egg-info dist build
	rm -rf skywalking-python*.tgz*
	find . -name "__pycache__" -exec rm -r {} +
	find . -name ".pytest_cache" -exec rm -r {} +
	find . -name "*.pyc" -exec rm -r {} +

release: clean lint license
	-tar -zcvf skywalking-python-src-$(VERSION).tgz --exclude venv *
	gpg --batch --yes --armor --detach-sig skywalking-python-src-$(VERSION).tgz
	shasum -a 512 skywalking-python-src-$(VERSION).tgz > skywalking-python-src-$(VERSION).tgz.sha512
