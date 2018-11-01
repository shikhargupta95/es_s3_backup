#!/bin/bash

#ES BACKUP SCRIPT
#Make sure allow the following line is added in the jvm.options file:   
#-Des.allow_insecure_settings=true  

#Default directory for es
ES_DIR="/usr/share/elasticsearch"
source variables
echo $ES_DIR/plugins/repository-s3

#check if the repository-s3 plugin is installed on the cluster;
#install the plugin in case the plugin does not exist
if [ ! -d "$ES_DIR/plugins/repository-s3" ]; then
    echo "repository-s3 Plugin Not found. Installing repository-s3 plugin."
    sudo $ES_DIR/bin/elasticsearch-plugin install repository-s3 
    #the action may prompt the user for permission
    #checking the exit status of the installation command for any failure
    if [ "$?" != 0 ]; then
        echo "Error Installing repository-s3 plugin."
        exit $?
    fi 

    echo "Elasticsearch needs to be restarted to install the plugin. Proceed (Y/N)?"
    read restart
    case $restart in 
        Y|y|yes|YES|Yes)
        
        echo "Restarting Elasticsearch"
        sudo systemctl stop elasticsearch.service
        sudo systemctl start elasticsearch.service
        sleep 5s
        ;;

        N|n|No|NO|no)
        
        echo "Elasticsearch needs to be restarted for the plugin to be enabled. Aborting script..."
        exit 2
        ;;
    esac
fi

#function to check status code for the urls
check_status_code()
{
    URI=$1
    FLAG=$2
    shift;shift;
    #the last argument as a json
    BODY=$@
    #checking if there is content in body
    if [ "$BODY" != "" ]; then  
        #Sending request for curl

        response="$(curl -i -o - --silent $FLAG --header 'Content-Type: application/json' --data "$BODY" $URI |grep HTTP    |awk '{print $2}')"
    else
        response=$(
            curl -$FLAG "$URI" \
                --write-out %{http_code} \
                --silent \
                --output /dev/null \
            )
    fi
}

#check if the backup repo exists
check_status_code $URL/_snapshot/$REPO XGET 
if [ $response == '404' ]; then
    _body='{
            "type":"s3",
            "settings":{
                "bucket":"'"$BUCKET_NAME"'",
                "region":"'"$REGION"'",
                "access_key":"'"$ACCESS_KEY"'",
                "secret_key":"'"$SECRET_KEY"'"
            }
            }'
    check_status_code $URL/_snapshot/$REPO XPUT $_body  
    case $response in 
        200|201)
        echo "Successfully registered s3 repository"
        ;;
        *)
        echo $response
        echo "Failed to register s3 repository"
        exit 2
    esac
fi

#triggering snapshots to s3
curl -XPUT "$URL/_snapshot/$REPO/$SNAPSHOT?wait_for_completion=true"
