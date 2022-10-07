#!/bin/bash

if [ "$(whoami)" != "sonarw" ]; then
  echo "Script must be run as user: 'sonarw'"
  exit 255
fi

## global variables and function

LOAD_VARS='. /etc/sysconfig/jsonar'
LOAD_CERT='CERT_AS_PASSWD=$(awk -vORS="\\\n" "1" ${JSONAR_LOCALDIR}/ssl/client/admin/cert.pem)'
SONARW='${JSONAR_BASEDIR}/bin/mongo --quiet --norc --port 27117 --authenticationMechanism PLAIN --authenticationDatabase "\$external" -u "CN=admin" -p"${CERT_AS_PASSWD}"'
SONARW_EXPORT='${JSONAR_BASEDIR}/bin/mongoexport --quiet --port 27117 --authenticationMechanism PLAIN --authenticationDatabase "\$external" -u "CN=admin" -p"${CERT_AS_PASSWD}" --jsonArray --jsonFormat=canonical --pretty'
SONARW_IMPORT='${JSONAR_BASEDIR}/bin/mongoimport --quiet --port 27117 --authenticationMechanism PLAIN --authenticationDatabase "\$external" -u "CN=admin" -p"${CERT_AS_PASSWD}" --jsonArray'

# $1=db, $2=command, $3=ssh
function sonarw_run() {
  if [[ $3 ]] ; then
    $3 "$LOAD_VARS; $LOAD_CERT; $SONARW \"'$1'\" --eval \"'$2'\""
  else
    eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW "'$1'" --eval "'$2'"
  fi
}

## start env report

echo -e "\nStarting environment stats report"

# export jsonar variables

. /etc/sysconfig/jsonar
JSONAR_DEBUGDIR=$(echo $JSONAR_LOCALDIR | sed 's/\/local/\/debug/')

# create report folder

report_folder_name=report_$(date +%Y%m%d%H%M%S)
report_location=$JSONAR_DEBUGDIR/$report_folder_name
mkdir $report_location

function add_to_report() {
  if [[ $3 ]] ; then
    echo -e "$2" | tr "$3" "\n" >> $report_location/$1
  else
    echo -e "$2" >> $report_location/$1
  fi
}

# get remote hosts

echo "1 - loading list of remote hosts ..."
remote_hosts=$(\grep -P "^Host ([^*]+)$" $HOME/.ssh/config | sed 's/Host //')
add_to_report "federation_report" "Remote hosts ($HOME/.ssh/config):\n"
add_to_report "federation_report" "$remote_hosts" " "
add_to_report "federation_report" "\n==========\n"

## start sizing operations

echo -e "\nStarting environment sizing stats operations"

# check ssh connection

echo "1 - testing ssh connection to each remote host ..."
add_to_report "federation_report" "Ssh connection test:\n"
for remote_host in $remote_hosts
do
  ssh_status=$(ssh -q -o BatchMode=yes -o ConnectTimeout=5 $remote_host echo ok 2>&1)
  add_to_report "federation_report" "$remote_host=$ssh_status"
done

add_to_report "federation_report" "\n==========\n"

# 

# $1=host, $2=ssh
function machine_info() {
  add_to_report "machine_info_report" "$1:"
  meminfo=$($2 \cat /proc/meminfo | \grep MemTotal | \awk '{print $1, $2/1000000, "GB"}')
  lscpu=$($2 \lscpu | \grep '^CPU(s):')
  add_to_report "machine_info_report" "  - meminfo: $(echo $meminfo)"
  add_to_report "machine_info_report" "  - lscpu: $(echo $lscpu)"
}

echo "2 - retrieving machine information for warehouse and remote hosts ..."

machine_info "warehouse"

for remote_host in $remote_hosts
do
  machine_info $remote_host "ssh -q $remote_host"
done

add_to_report "machine_info_report" "\n==========\n"

## start sonarw operations

echo -e "\nStarting sonarw data retrieval operations"

count_assets='{"$match":{"$and":[{"asset_id":{"$ne":"lmrm__sonarw"}},{"asset_id":{"$ne":"mailer"}}]}},{"$group":{"_id":"$Server Type","count":{"$sum":1}}}'

echo "1 - retrieving asset info from warehouse ..."

asset_info=$(sonarw_run "lmrm__sonarg" "db.asset.aggregate($count_assets)")
asset_info_clean=$(echo "$asset_info" | awk -F "\"" '{print $4 = sprintf("%-24s", $4), substr($7, 2, length($7)-2)}')
add_to_report "asset_info_report" "warehouse:\n"
add_to_report "asset_info_report" "$asset_info_clean"
add_to_report "asset_info_report" "\n==========\n"

echo "2 - retrieving asset info from remote hosts ..."

for remote_host in $remote_hosts ; do
  asset_info=$(sonarw_run "lmrm__sonarg" "db.asset.aggregate($count_assets)" "ssh -q $remote_host")
  asset_info_clean=$(echo "$asset_info" | awk -F "\"" '{print $4 = sprintf("%-24s", $4), substr($7, 2, length($7)-2)}')
  add_to_report "asset_info_report" "$remote_host:\n"
  add_to_report "asset_info_report" "$asset_info_clean"
  add_to_report "asset_info_report" "\n==========\n"
done

echo "3 - calculating sonargd collections average daily (past 7 days) from warehouse ..."

declare -A sonargd
sonargd[session]='Session Start'
sonargd[exception]='Exception Timestamp'
sonargd[instance]='Period Start'
sonargd[full_sql]='Timestamp'

function average_daily(){
  echo -e '{"$match":{"$and":[{"$expr":{"$gte":["$'$1'",{"$subtract":[{"$now":1},6048000000]}]}}]}},{"$group":{"_id":"all","count":{"$sum":1}}}'
}

for collection in "${!sonargd[@]}"; do
  echo "  - $collection: ${sonargd[$collection]}"
  agg=$(average_daily "${sonargd[$collection]}")
  coll_avg=$(sonarw_run "sonargd" "db.$collection.aggregate($agg)")
  add_to_report "sonargd_collections_report" "$collection\n"
  add_to_report "sonargd_collections_report" "$coll_avg_clean"
  add_to_report "sonargd_collections_report" "\n==========\n"
done

echo "4 - retriving active UEBA models information from warehouse ..."

ueba_models='{"$match":{"$and":[{"name":{"$regex":"^__ae_UEBA"}},{"paused":false}]}},{"$project":{"engine":{"$arrayElemAt":[{"$split":["$name", " - "]},1]},"_id":0}}'
ueba_res=$(sonarw_run "lmrm__scheduler" "db.lmrm__scheduled_jobs.aggregate($ueba_models)")
add_to_report "ueba_models_report" "$ueba_res"

# finished

echo -e "\nFinished.\n"
echo -e "Report location:"
echo -e "$report_location\n" 

exit 0
