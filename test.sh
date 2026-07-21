#!/bin/bash
set -x
yq --version

yq e '(.siteinfo[] | select(.domain == "panda-test2.net-chef.com")).disable = true' test.yaml

