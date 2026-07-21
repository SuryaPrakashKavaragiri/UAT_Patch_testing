#!/bin/bash

yq --version


yq e '
.siteinfo |= map(
  if .domain == "panda-test2.net-chef.com"
  then
    . + {"disable": true}
  else
    .
  end
)
' test.yaml

