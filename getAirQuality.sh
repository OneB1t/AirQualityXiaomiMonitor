#!/bin/bash

DB_NAME=${DB_NAME:=airpurifier}
DB_URL=${DB_URL:=https://endpoint.global}
DB_USERNAME=${DB_USERNAME:=}
DB_PASSWORD=${DB_PASSWORD:=}
DB_MEASUREMENTS_TAGS=${DB_MEASUREMENTS_TAGS:=DEVICE_NAME=xiaomi_1}
DB_TEMPERATURE_MEASUREMENT_NAME=${DB_TEMPERATURE_MEASUREMENT_NAME:=temperature}
DB_HUMIDITY_MEASUREMENT_NAME=${DB_HUMIDITY_MEASUREMENT_NAME:=humidity}
DB_PM2_5_MEASUREMENT_NAME=${DB_PM2_5_MEASUREMENT_NAME:=pm2_5}
SENDING_INTERVAL_IN_SECONDS=${SENDING_INTERVAL_IN_SECONDS:=10}
LOGGING_LEVEL=${LOGGING_LEVEL:=ERROR}
DEVICE_HOST=192.168.1.1
DEVICE_TOKEN=REPLACE_THIS_WITH_DEVICE_TOKEN

declare -A levels=([DEBUG]=0 [INFO]=1 [ERROR]=2)

logThis() {
    local log_message=$1
    local log_priority=$2

    #check if level exists
    [[ ${levels[$log_priority]} ]] || return 1

    #check if level is enough
    (( ${levels[$log_priority]} < ${levels[$LOGGING_LEVEL]} )) && return 2

    #log here
    echo "$(date -u +"%F %T %Z") : ${log_priority} : ${log_message}"
}
while true
do
        logThis "Acquiring measurements..." "INFO"
        logThis "Acquiring temperature from ${DEVICE_HOST}..." "DEBUG"
        TEMPERATURE=`miiocli airpurifier --ip ${DEVICE_HOST} --token ${DEVICE_TOKEN} raw_command get_prop "['temp_dec']" | tr -dc '0-9'`
        if (( ($TEMPERATURE+0) > 1000 )); then
            continue;
        fi

        logThis "Acquiring relative humidity from ${DEVICE_HOST}..." "DEBUG"
        HUMIDITY=`miiocli airpurifier --ip ${DEVICE_HOST} --token ${DEVICE_TOKEN} raw_command get_prop "['humidity']" | tr -dc '0-9'`


        if (( ($HUMIDITY+0) > 100 )); then
            continue;
        fi

        logThis "Acquiring PM2.5 from ${DEVICE_HOST}..." "DEBUG"
        PM2_5=`miiocli airpurifier --ip ${DEVICE_HOST} --token ${DEVICE_TOKEN} raw_command get_prop "['aqi']" | tr -dc '0-9'`

        if (( ($PM2_5+0) > 1000 )); then
            continue;
        fi


        logThis "Temperature: ${TEMPERATURE}, Humidity: ${HUMIDITY}, PM2.5: ${PM2_5}" "INFO"

        logThis "Sending measurements to InfluxDB at ${DB_URL}..." "INFO"

        curl_options="-v"
        case ${LOGGING_LEVEL} in
                "ERROR")
                        curl_options="--silent --show-error"
                        ;;
                "INFO")
                        curl_options="-s -o /dev/null -I -w \"\n%{http_code}\""
                        ;;
        esac

        curl_output=$(curl ${curl_options} -XPOST -u "${DB_USERNAME}:${DB_PASSWORD}" "${DB_URL}/write?db=${DB_NAME}" --data-binary "${DB_TEMPERATURE_MEASUREMENT_NAME},${DB_MEASUREMENTS_TAGS} value=${TEMPERATURE}
${DB_HUMIDITY_MEASUREMENT_NAME},${DB_MEASUREMENTS_TAGS} value=${HUMIDITY}
${DB_PM2_5_MEASUREMENT_NAME},${DB_MEASUREMENTS_TAGS} value=${PM2_5}");

        logThis "Sleeping for ${SENDING_INTERVAL_IN_SECONDS} seconds..." "INFO"
        sleep ${SENDING_INTERVAL_IN_SECONDS}
done
