#!/bin/bash

installHelm () {
    curl -s -X GET https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
    chmod 700 get_helm.sh
    ./get_helm.sh
    helm init --client-only -c --skip-refresh
}

installCli () {
    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/cicd.sh > cicd
    chmod +x cicd
    mv cicd /usr/local/bin
    cicd welcome
}

installHelm
installCli