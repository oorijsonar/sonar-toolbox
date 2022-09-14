#!/bin/bash

if [ "$(whoami)" != "sonarw" ]; then
  echo "Script must be run as user: 'sonarw'"
  exit 255
fi

## global variables and function

LOAD_VARS='. /etc/sysconfig/jsonar'
LOAD_CERT='CERT_AS_PASSWD=$(awk -vORS="\\\n" "1" ${JSONAR_LOCALDIR}/ssl/client/admin/cert.pem)'
SONARW='${JSONAR_BASEDIR}/bin/mongo --quiet --norc --port 27117 --authenticationMechanism PLAIN --authenticationDatabase "\$external" -u "CN=admin" -p"${CERT_AS_PASSWD}"'

# $1=db, $2=command
function sonarw_run() {
  eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW '$1' --eval '$2'
}

USAGE_1="<report folder name> [asset|connection] next"
USAGE_2="<report folder name> [asset|connection] skip <asset id>"
USAGE_3="<report folder name> [asset|connection] dedup <asset id> <index to use>"
USAGE_4="<report folder name> [asset|connection] revert <asset id>"
if [ ! $# -gt 2 ]; then
  echo "Usage: $0 $USAGE_1"
  echo "       $0 $USAGE_2"
  echo "       $0 $USAGE_3"
  echo "       $0 $USAGE_4"
  exit 255
fi

. /etc/sysconfig/jsonar
JSONAR_DEBUGDIR=$(echo $JSONAR_LOCALDIR | sed 's/\/local/\/debug/')

report_folder_name=$1
report_location=$JSONAR_DEBUGDIR/$report_folder_name
report_db="federation_$report_folder_name"

if [ ! -d "$1" ]; then
  echo "Error: report folder '$1' does not exist."
  echo "Usage: $0 $USAGE_1"
  echo "       $0 $USAGE_2"
  echo "       $0 $USAGE_3"
  echo "       $0 $USAGE_4"
  exit 255
fi

coll_dedup="$2_2_dedup"
coll_final="$2_3_final"
asset_id="$4"
index="$5"

if [ "$3" = "skip" ]; then

  sonarw_run "$report_db" "db.$coll_dedup.update({_id:\"$asset_id\"},{\$currentDate:{skip:true}})"

elif [ "$3" = "next" ]; then

  sonarw_run "$report_db" "db.$coll_dedup.aggregate({\$match:{\$or:[{count_head:{\$gt:1}},{count_body:{\$gt:1}}],fixed:{\$ne:true}}},{\$sort:{skip:1}},{\$limit:1}).pretty()"

elif [ "$3" = "dedup" ]; then

  sonarw_run "$report_db" "db.$coll_dedup.update({_id:\"$asset_id\"},{\$set:{fixed:true}})"
  pick_agg="{\$match:{_id:\"$asset_id\"}},{\$project:{\"*\":1,pick:{\$mergeObjects:[{\$arrayElemAt:[\"\$head_to_compare_set\",$index]},{\$arrayElemAt:[\"\$body_to_compare_set\",$index]}]}}},{\$out:{name:\"$coll_final\",append:true}}"
  sonarw_run "$report_db" "db.$coll_dedup.aggregate($pick_agg)"
  sonarw_run "$report_db" "db.$coll_final.find({_id:\"$asset_id\"}).pretty()"

elif [ "$3" = "revert" ]; then

  sonarw_run "$report_db" "db.$coll_dedup.update({_id:\"$asset_id\"},{\$unset:{fixed:true,skip:true}})"
  sonarw_run "$report_db" "db.$coll_final.remove({_id:\"$asset_id\"})"

else
  echo "Usage: $0 $USAGE_1"
  echo "       $0 $USAGE_2"
  echo "       $0 $USAGE_3"
  echo "       $0 $USAGE_4"
  exit 255
fi

exit 0
