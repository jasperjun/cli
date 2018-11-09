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
            createChart)
                shift
                cmd="createChart"
                ;;
            createJob)
                shift
                cmd="createJob"
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
        createJob)
            createJob
            ;;
        createChart)
            createChart
            ;;
        token)
            token
            echo $token
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
        ok [command] <args>
    eg:
        1. first init jenkins conf
        ok init --url http://jenkins.docker.okcoin-inc.com --user dev:dev

        2. create helm chart template for Kubernetes
        ok createChart --name okcoin-users-rest

        3. create pipeline jenkinsfile template for CI/CD
        ok createJob

        4. publish pipeline job to Jenkins
        ok apply --name job-okcoin-users

        6. build pipeline job by manual
        ok build --name job-okcoin-users

        7. delete pipeline job
        ok del --name job-okcoin-users

    Available Commands:
        init        initilize jenkins config information.
        token       generate gitlab webhook secret token.
        createJob   create pipeline jenkinsfile template for CI/CD.
        createChart create helm chart template for Kubernetes.
        apply       publish pipeline job to Jenkins
        del         delete pipeline job.
        build       build pipeline job by manual.
        config      list jenkins config information.

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
    token=${token//\n//\\}
    len=${#token}
    token=${token:0:$len}
}

createJob () {

    input "Input Project GitLab URL:" git_url

    git_branch=`git symbolic-ref --short -q HEAD`
    if [ "$git_branch" != "" ]; then
        input "Use Current Branch $git_branch [y/n]" ret
        if [[ "$ret" == "n" || "$ret" == "N" ]]; then
            git_branch=""
        fi
    fi
    if [ "$git_branch" == "" ]; then
        input "Input Project GitLab Branch:" git_branch
    fi

    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/spec/job-config.xml > ./job-config.xml
    token
    sedJob

    curl -s -X GET https://raw.githubusercontent.com/jasperjun/cli/master/spec/Jenkinsfile.sample > ./Jenkinsfile.sample
    echo "GitLab integrations hook by the following Secret Token:"
    echo $token

    bingo
}

input () {
    read -p "$1" "$2"
}

sedJob () {
    sed -i '' -e "s/\${SECRET_TOKEN}/${token}/g"  job-config.xml
    sed -i ''  -e "s/\${GIT_URL}/${git_url//\//\\/}/g"  job-config.xml
    sed -i ''  -e "s/\${GIT_BRANCH}/$git_branch/g" job-config.xml
}

sedChart () {
    for file in `ls $1`
    do
        if [ -d $1"/"$file ]
        then
            sedChart $1"/"$file
        else
            __debug "sed $1/$file"
            sed -i '' -e "s/\${CHART_NAME}/${chartname}/g" $1/$file
        fi
    done
}

createChart () {
    if !(type helm > /dev/null 2>&1); then
        __error "helm not install."
        exit 1
    fi
    chartname=$name
    if [ "$chartname" == "" ]; then
        input 'Input Chart Name:' chartname
    fi

    mkdir -p ./_chart

    curl -X GET https://raw.githubusercontent.com/jasperjun/cli/master/spec/chart.tar.gz > ./_chart/chart.tar.gz

    if [ ! -f ./_chart/chart.tar.gz ]; then
        __error "Can not download chart template gz."
        exit 1
    fi

    cd ./_chart

    tar -xf ./chart.tar.gz

    cd ..

    mkdir -p "./charts/$chartname"

    cp -r ./_chart/chart/* "charts/$chartname"

    rm -rf ./_chart

    sedChart ./charts/$chartname

    bingo
}

bingo(){
    echo "Bingo!!! ^_^"
}

__debug(){
    if $debug; then
        echo "[DEBUG] $@"
    fi
}

__info(){
    echo "[INFO] $@"
}

__error(){
    echo "[ERROR] $@"
}

__welcome() {
    echo "Run 'ok init' to configure cli"
    echo "Have Fun! ^_^"
}

echo "       _               _       "
echo "      | |             (_)      "
echo "  ___ | |  _ ____ ___  _ ____  "
echo " / _ \| |_/ ) ___) _ \| |  _ \ "
echo "| |_| |  _ ( (__| |_| | | | | |"
echo " \___/|_| \_)____)___/|_|_| |_|"

processOptions $@
main
exit 0