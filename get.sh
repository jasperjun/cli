#!/bin/bash

set +u

curl -o cicd -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/cicd.sh

chmod +x cicd

mv cicd /usr/local/bin

cicd welcome