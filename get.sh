#!/bin/bash

installHelm () {
    curl -s -X GET https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
    chmod 700 get_helm.sh
    ./get_helm.sh
    helm init --client-only -c --skip-refresh
    rm -f get_helm.sh
}

installCli () {
    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/ok.sh > ok
    chmod +x ok
    mv ok /usr/local/bin
    ok welcome
}

installHelm
installCli