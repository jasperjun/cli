#!/bin/bash


processOptions () {
    if [ $# -eq 0 ]; then
        usage
    fi

    file="job-config.xml"
    debug=false

    for arg in "$@"; do
        case $arg in
            welcome)
                shift
                cmd="wel"
                ;;
            createApp)
                shift
                cmd="createApp"
                ;;
            token)
                shift
                cmd="token"
                ;;
            apply)
                shift
                cmd="apply"
                ;;
            del)
                shift
                cmd="del"
                ;;
            init)
                shift
                cmd="init"
                ;;
            build)
                shift
                cmd="build"
                ;;
            config)
                shift
                cmd="config"
                ;;
            --debug)
                shift
                debug=true
                ;;
            --help)
                shift
                usage
                ;;
            --url)
                shift
                url=$1
                ;;
            --name)
                shift
                name=$1
                ;;
            --user)
                shift
                user=$1
                ;;
            --file)
                shift
                file=$1
                ;;
            *)
               shift
               ;;
        esac
    done

}

main () {

    if $debug; then
    echo -e "\nRunning"
    echo "cmd:  ${cmd}"
    echo "url:  ${url}"
    echo "file:  ${file}"
    echo "user:  ${user}"
    echo "name:  ${name}"
    fi

    case $cmd in
        wel)
            __welcome
            ;;
        createApp)
            createApp
            ;;
        token)
            token
            ;;
        apply)
            apply
            ;;
        init)
            init
            ;;
        del)
             del
            ;;
        build)
            build
            ;;
        config)
            debug=true
            config
            ;;
        --help)
            usage
            exit 1
            ;;
        *)
           usage
           exit 1
           ;;
    esac
}

usage() {
echo "
    Usage:
        cicd [command] <args>
    eg:
        1. first init jenkins conf
        cicd init --url http://jenkins.docker.okcoin-inc.com --user dev:dev

        2. generate gitlab hook secret token
        cicd token

        3. add|update job
        cicd apply --name okcoin-users-job

        4. build job
        cicd build --name okcoin-users-job

    Available Commands:
        init      initilize jenkins config information.
        token     generate gitlab webhook secret token
        apply     add|update cicd job.
        del       delete cicd job.
        build     trigger cicd job build.
        config    list jenkins config information.

    Available Arguments:
        --url     init jenkins url
        --name    job name
        --file    job config xml file [default job-config.xml]
        --user    jenkins account:password eg: dev:dev
"
}


init() {
    __info "init jenkins config ..."

    if [ ! -f ~/.jenkins ]; then
        mv ~/.jenkins
    fi
    if [ "$user" == "" ]; then
        read -p "input username and password <username:password>:" user
    fi
    if [ "$url" == "" ]; then
        read -p "input jenkins host url:" url
    fi
    echo > ~/.jenkins
    echo "url=$url" >> ~/.jenkins
    echo "user=$user" >> ~/.jenkins
    readConf
}

config() {
    readConf
}

readConf() {
    if [ ! -f ~/.jenkins ]; then
        __info "init command first."
        exit 1
    fi

    for line in `cat ~/.jenkins`
    do
        if [[ "$line" =~ "url=" && "$url" == "" ]]; then
            url=${line:4}
        fi
        if [[ "$line" =~ "user=" && "$user" == "" ]]; then
            user=${line:5}
        fi
    done

    if $debug ;then
        echo "read ~/.jenkins:"
        echo "url=${url}"
        echo "user=${user}"
    fi
}

apply() {
    readConf
    inputUrl apply
    inputName apply
    inputUser apply

    existsJob

    if [ "$code" == "200" ]; then
        __info "update job $name"
        callJenkins -X POST $url/job/$name/config.xml --data-binary "@$file" -H "Content-Type: text/xml"

    elif [ "$code" == "404" ]; then
        __info "add new job $name"
        callJenkins -X POST $url/createItem?name=$name --data-binary "@$file" -H "Content-Type: text/xml"
    fi

    if [ "$code" != "200" ]; then
        __error "fail to add job $name, http[$code], more information see cicd.log. "
        exit 1
    fi
    __info "Bingo!!! :)"
}

del() {
    readConf
    inputUrl delete
    inputName delete
    inputUser delete

    read -p "confirm delete job $name [y/n]:" ret

    if [ "$ret" != "y" ]; then
        __info "cancel delete job $name."
        exit 0
    fi

    existsJob

    if [ "$code" != "200" ]; then
        __error "job not exists, http[$code], more information see cicd.log "
        exit 1
    fi

    __info "deleting job $name ..."
    callJenkins -X POST $url/job/$name/doDelete

    if [[ "$code" != "200" && "$code" != "302" ]]; then
        __error "fail to delete $name, http[$code], more information see cicd.log"
        exit 1
    fi
    __info "Bingo :)"
}

build () {
    readConf
    inputUrl build
    inputName build
    inputUser build

    existsJob

    if [ "$code" != "200" ]; then
        __error "job not exists, http[$code], more information see cicd.log "
        exit 1
    fi

    __info "building job $name ..."
    callJenkins -X POST $url/job/$name/build

    if [[ "$code" != "200" && "$code" != "201" ]]; then
        __error "fail to build $name, http[$code], more information see cicd.log"
    fi
    __info "Bingo :)"
}

callJenkins() {
    if $debug; then
        __debug curl -o cicd.log -s -w %{http_code} --user $user "$@"
    fi
    code=`curl -o cicd.log -s -w %{http_code} --user $user "$@"`
}

existsJob() {
    if $debug; then
        __debug curl -o cicd.log -s -w %{http_code} -X GET $url/job/$name/config.xml --user $user
    fi
    code=`curl -o cicd.log -s -w  %{http_code} -X GET $url/job/$name/config.xml --user $user`
    return $code
}

inputName () {
    while [ "$name" == "" ]; do
        read -p "input $1 job name:" name
    done
}

inputUrl () {
    while [ "$url" == "" ]; do
        read -p "input $@ url:" url
    done
}

inputUser () {
    while [ "$user" == "" ]; do
        read -p "input $@ <username:password>:" user
    done
}

token () {
    readConf
    inputUser token

    if $debug; then
        echo "curl -I -s -X POST $url/job/demo/descriptorByName/com.dabsquared.gitlabjenkins.GitLabPushTrigger/generateSecretToken --user $user | grep script | cut -d '=' -f 2"
    fi
    echo "generate token ..."
    token=`curl -I -s -X POST $url/job/demo/descriptorByName/com.dabsquared.gitlabjenkins.GitLabPushTrigger/generateSecretToken --user $user | grep script | cut -d '=' -f 2 | sed "s/'//g"`
    echo $token
}

createApp () {
    input "input git url:" git_url
    input "input git branch:" git_branch

    mkdir -p ./charts
    mkdir -p ./jobs

    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/spec/job-config.xml > job-config.xml

    token
    echo $git_url
    echo $git_branch

    sedJob

    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/spec/Jenkinsfile.sample > Jenkinsfile.sample

    bingo
}

sedJob () {
    sed "/s/\$\{SECRET_TOKEN}/$token/g" ./job-config.xml
    sed "/s/\$\{GIT_URL}/$git_url/g" ./job-config.xml
    sed "/s/\$\{GIT_BRANCH}/$git_branch/g" ./job-config.xml
}

input () {
    read -p "$1" "$2"
}

createChart () {
    if !(type helm > /dev/null 2>&1); then
        __error "helm not install."
        exit 1
    fi
    inputName
    helm create ./charts/
    bingo
}

bingo(){
    echo "Bingo!!! ^_^"
}

__debug(){
    echo "[DEBUG] $@"
}

__info(){
    echo "[INFO] $@"
}

__error(){
    echo "[ERROR] $@"
}

__welcome() {
    echo "Run 'cicd init' to configure cicd cli"
    echo "Happy cicd! ^_^"
}

echo "        _               _"
echo "       (_)             | |"
echo "  ___   _     ___    __| |"
echo " / __| | |   / __|  / _\` |"
echo "| (__  | |  | (__  | (_| |"
echo " \___| |_|   \___|  \__,_|"

processOptions $@
main
exit 0