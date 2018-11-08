#!/bin/bash


set +u

curl -o cicd -X GET http://gitlab.okcoin-inc.com/jun.zhang/cli/blob/master/cicd.sh

chmod +x cicd

mv cicd /usr/local/bin

cicd