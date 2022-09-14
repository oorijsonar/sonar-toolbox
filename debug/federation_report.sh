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

# $1=db, $2=command, $3=output file, $4=ssh
function sonarw_eval() {
  if [[ $4 ]] ; then
    $4 "$LOAD_VARS; $LOAD_CERT; $SONARW '$1' --eval '$2'" > $report_location/$3
  else
    eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW '$1' --eval '$2' > $report_location/$3
  fi
}

# $1=db, $2=command, $3=ssh
function sonarw_run() {
  if [[ $3 ]] ; then
    $3 "$LOAD_VARS; $LOAD_CERT; $SONARW '$1' --eval '$2'" > /dev/null
  else
    eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW '$1' --eval '$2' > /dev/null
  fi
}

# $1=db, $2=coll, $3=file, $4=ssh
function sonarw_export() {
  if [[ $4 ]] ; then
    $4 "$LOAD_VARS; $LOAD_CERT; $SONARW_EXPORT --db '$1' --collection '$2'" > $report_location/$3
  else
    eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW_EXPORT --db '$1' --collection '$2' > $report_location/$3
  fi
}

# $1=db, $2=coll, $3=file
function sonarw_import() {
  eval $LOAD_VARS && eval $LOAD_CERT && eval $SONARW_IMPORT --db '$1' --collection '$2' --file "$3" > /dev/null
}

## start federation report

echo -e "\nStarting federation report"

# export jsonar variables

. /etc/sysconfig/jsonar
JSONAR_DEBUGDIR=$(echo $JSONAR_LOCALDIR | sed 's/\/local/\/debug/')

# create report folder

if [ -z "$1" ]; then
  report_folder_name=report_$(date +%Y%m%d%H%M%S)
  report_location=$JSONAR_DEBUGDIR/$report_folder_name
  report_db="federation_$report_folder_name"
  mkdir $report_location
  reimport="--reimport"
else
  report_folder_name=$1
  report_location=$JSONAR_DEBUGDIR/$report_folder_name
  report_db="federation_$report_folder_name"
fi

if [ -n "$2" ]; then
  reimport="$2"
fi

function add_to_report() {
  if [[ $3 ]] ; then
    echo -e "$2" | tr "$3" "\n" >> $report_location/$1
  else
    echo -e "$2" >> $report_location/$1
  fi
}

if [ -z "$1" ]; then

  # get remote hosts

  echo "1 - loading list of remote hosts ..."
  remote_hosts=$(\grep -P "^Host ([^*]+)$" $HOME/.ssh/config | sed 's/Host //')
  add_to_report "federation_report" "Remote hosts ($HOME/.ssh/config):\n"
  add_to_report "federation_report" "$remote_hosts" " "
  add_to_report "federation_report" "\n==========\n"

  ## start ssh and file operations

  echo -e "\nStarting outgoing/incoming operations"

  # check ssh connection

  echo "1 - testing ssh connection to each remote host ..."
  add_to_report "federation_report" "Ssh connection test:\n"
  for remote_host in $remote_hosts
  do
    ssh_status=$(ssh -q -o BatchMode=yes -o ConnectTimeout=5 $remote_host echo ok 2>&1)
    add_to_report "federation_report" "$remote_host=$ssh_status"
  done

  add_to_report "federation_report" "\n==========\n"

  # check outgoing/incoming files

  # $1=host, $2=location, $3=label, $4=ssh
  function list_and_count() {
    add_to_report "federation_report" "$1 - $3"
    add_to_report "federation_report" "    - $3 location: $2"
    ls_files=$($4 \ls $2)
    if [[ -z $ls_files ]] ; then
      add_to_report "federation_report" "    - $3 total file count: 0"
    else
      add_to_report "federation_report" "    - $3 total file count: $(echo $ls_files | tr ' ' '\n' | wc -l)"
      add_to_report "federation_report" "    - $3 'export_assets' file count: $(echo $ls_files | tr ' ' '\n' | \grep export_assets | wc -l)"
      add_to_report "federation_report" "    - $3 'export_connections' file count: $(echo $ls_files | tr ' ' '\n' | \grep export_connections | wc -l)"
      add_to_report "federation_files" "$1:$2\n"
      $4 \ls -l $2 | while read ls_line
      do
        add_to_report "federation_files" "$ls_line"
      done
      add_to_report "federation_files" "\n==========\n"
    fi

  }

  echo "2 - retrieving outgoing/incoming information for warehouse and remote hosts ..."
  add_to_report "federation_report" "Checking sonargd.conf sftp and retriving outgoing/incoming folder information:\n"

  outgoing_location="$JSONAR_DATADIR/sonargd/outgoing"
  list_and_count "warehouse" $outgoing_location "outgoing"

  incoming_location="$JSONAR_DATADIR/sonargd/incoming"
  list_and_count "warehouse" $incoming_location "incoming"

  for remote_host in $remote_hosts
  do
    grep_sonargd=$(\grep $remote_host $JSONAR_LOCALDIR/sonargd/sonargd.conf| sed 's/ *- *//')
    outgoing_location=$(echo $grep_sonargd | sed 's/.*'$remote_host'//')
    list_and_count $remote_host $outgoing_location "outgoing" "ssh -q $remote_host"

    dispatcher_remote_host=$(echo $remote_host | sed 's/remote_//' | sed 's/_/./g')
    grep_dispatcher=$(grep -Pzio "(?s)($dispatcher_remote_host).*?(copy_dest)\N*" $JSONAR_LOCALDIR/dispatcher/dispatcher.conf | grep copy_dest)
    incoming_location=$(echo $grep_dispatcher | sed 's/copy_dest = //')
    list_and_count $remote_host $incoming_location "incoming" "ssh -q $remote_host"

  done

  add_to_report "federation_report" "\n==========\n"

  ## start sonarw operations

  echo -e "\nStarting data retrieval operations"

  echo "1 - retrieving assets/connections/jobs from remote hosts ..."

  mkdir $report_location/coll_asset
  mkdir $report_location/coll_connection
  mkdir $report_location/coll_asset_stats
  mkdir $report_location/coll_connection_stats
  mkdir $report_location/coll_scheduled_jobs


  massage='{"$project":{"_id":1,"root":{"$arrayToObject":{"$sorted":{"$objectToArray":"$$ROOT"}}}}},{"$replaceRoot":{"newRoot":"$root"}}'

  for remote_host in $remote_hosts ; do
    echo "   - from $remote_host ..."
    sonarw_run "lmrm__sonarg" "db.asset.aggregate({\"\$project\":{\"*\":1,\"__federation_source\":\"$remote_host\"}},$massage,{\"\$out\":{\"db\":\"lmrm__sonarg\",\"name\":\"asset_report\"}})" "ssh -q $remote_host"
    sonarw_export "lmrm__sonarg" "asset_report" "coll_asset/$remote_host.json" "ssh -q $remote_host"
    sonarw_run "lmrm__sonarg" "db.connection.aggregate({\"\$project\":{\"*\":1,\"__federation_source\":\"$remote_host\"}},$massage,{\"\$out\":{\"db\":\"lmrm__sonarg\",\"name\":\"connection_report\"}})" "ssh -q $remote_host"
    sonarw_export "lmrm__sonarg" "connection_report" "coll_connection/$remote_host.json" "ssh -q $remote_host"
    sonarw_eval "lmrm__sonarg" "db.asset.stats()" "coll_asset_stats/$remote_host" "ssh -q $remote_host"
    sonarw_eval "lmrm__sonarg" "db.connection.stats()" "coll_connection_stats/$remote_host" "ssh -q $remote_host"
    sonarw_eval "lmrm__scheduler" "db.lmrm__scheduled_jobs.aggregate({\"\$match\":{\"name\":/export_(assets|connections).*/}},{\"\$project\":{\"*\":1,\"__federation_source\":\"$remote_host\"}}).toArray()" "coll_scheduled_jobs/$remote_host" "ssh -q $remote_host"
  done

  echo "2 - retrieving assets/connections from warehouse ..."

  sonarw_run "lmrm__sonarg" "db.asset.aggregate({\"\$project\":{\"*\":1,\"__federation_source\":\"warehouse\"}},$massage,{\"\$out\":{\"db\":\"lmrm__sonarg\",\"name\":\"asset_report\"}})"
  sonarw_export "lmrm__sonarg" "asset_report" "coll_asset/warehouse.json"
  sonarw_run "lmrm__sonarg" "db.connection.aggregate({\"\$project\":{\"*\":1,\"__federation_source\":\"warehouse\"}},$massage,{\"\$out\":{\"db\":\"lmrm__sonarg\",\"name\":\"connection_report\"}})"
  sonarw_export "lmrm__sonarg" "connection_report" "coll_connection/warehouse.json"

else

  echo -e "\n... skipping retrieval steps and using data from '$1'\n"

fi

if [ -n "$reimport" ]; then
  # import data into sonarw

  echo -e "\nImporting retrived data into warehouse"

  echo "1 - importing assets into warehouse report db ..."

  sonarw_run "$report_db" "db.asset_1_union.drop()"
  sonarw_run "$report_db" "db.createCollection(\"asset_1_union\")"
  sonarw_run "$report_db" "db.runCommand({\"allow_duplicate_ids\":{\"asset_1_union\":true}})"

  for json_file in $report_location/coll_asset/*.json ; do
    sonarw_import "$report_db" "asset_1_union" "$json_file"
  done

  echo "2 - importing connections into warehouse report db ..."

  sonarw_run "$report_db" "db.connection_1_union.drop()"
  sonarw_run "$report_db" "db.createCollection(\"connection_1_union\")"
  sonarw_run "$report_db" "db.runCommand({\"allow_duplicate_ids\":{\"connection_1_union\":true}})"

  for json_file in $report_location/coll_connection/*.json ; do
    sonarw_import "$report_db" "connection_1_union" "$json_file"
  done

fi

# merge into set to remove duplicates

echo -e "\nStarting dedup operations"

echo "1 - attempting to remove duplicates ..."

o='{"$optimizer":false}'
a='{"$project":{"_id":"$asset_id","head_to_compare":[{"_id":"$_id","__federation_source":"$__federation_source","audit_pull_enabled":"$audit_pull_enabled","jsonar_uid":"$jsonar_uid","jsonar_uid_display_name":"$jsonar_uid_display_name","timestamp":"$timestamp","gateway_service":"$gateway_service"}],"body_to_compare":"$$ROOT"}}'
b='{"$project":{"*":1,"body_to_compare._id":0,"body_to_compare.__federation_source":0,"body_to_compare.audit_pull_enabled":0,"body_to_compare.jsonar_uid":0,"body_to_compare.jsonar_uid_display_name":0,"body_to_compare.timestamp":0,"body_to_compare.gateway_service":0}}'
c='{"$project":{"*":1,"head_to_compare":{"$arrayElemAt":["$head_to_compare",0]},head_to_diff:{"$arrayElemAt":["$head_to_compare",0]}}}'
d='{"$project":{"*":1,"head_to_compare.__federation_source":0,order:{$cond:{if:{$eq:["$head_to_diff.__federation_source","warehouse"]},then:"0",else:"1"}}}}'
e='{"$sort":{"order":1,"__federation_source":1}}'
f='{"$group":{"_id":"$_id","head_to_compare_diff":{"$diff":"$head_to_diff"},"head_to_compare_set":{"$addToSet":"$head_to_compare"},"body_to_compare_diff":{"$diff":"$body_to_compare"},"body_to_compare_set":{"$addToSet":"$body_to_compare"}}}'
g='{"$project":{"*":1,"head_to_compare_diff":{"$cond":{"if":{"$eq":[{"$size":"$head_to_compare_set"},1]},"then":"$$REMOVE","else":"$head_to_compare_diff"}},"body_to_compare_diff":{"$cond":{"if":{"$eq":[{"$size":"$body_to_compare_set"},1]},"then":"$$REMOVE","else":"$body_to_compare_diff"}}}}'
h='{"$project":{"*":1,"count_head":{"$size":"$head_to_compare_set"},"count_body":{"$size":"$body_to_compare_set"},"pick":{"$cond":{"if":{"$and":[{"$eq":[{"$size":"$head_to_compare_set"},1]},{"$eq":[{"$size":"$body_to_compare_set"},1]}]},"then":{"$mergeObjects":[{"$arrayElemAt":["$head_to_compare_set",0]},{"$arrayElemAt":["$body_to_compare_set",0]}]},"else":"conflict"}}}}'
set_agg="$o,$a,$b,$c,$d,$e,$f,$g,$h"

sonarw_run "$report_db" "db.asset_1_union.aggregate($set_agg,{\"\$out\":\"asset_2_dedup\"})"
sonarw_run "$report_db" "db.connection_1_union.aggregate($set_agg,{\"\$out\":\"connection_2_dedup\"})"

# create final asset collection ignoring conflicts

sonarw_run "$report_db" "db.asset_2_dedup.aggregate({\"\$match\":{\"pick\":{\$ne:\"conflict\"}}},{\"\$out\":\"asset_3_final\"})"
sonarw_run "$report_db" "db.connection_2_dedup.aggregate({\"\$match\":{\"pick\":{\$ne:\"conflict\"}}},{\"\$out\":\"connection_3_final\"})"

# create asset/connection overview report

echo "2 - creating asset/connection overview report ..."

report_agg='{"$group":{_id:"overview","total":{"$sum":1},"conflicts":{"$group":{"_id":{"$cond":{"if":{"$eq":["$pick","conflict"]},"then":"conflict","else":"ok"}},"count":{"$sum":1}}}}}'
sonarw_eval "$report_db" "db.asset_2_dedup.aggregate($report_agg).toArray()" "federation_asset_dedup_overview"
sonarw_eval "$report_db" "db.connection_2_dedup.aggregate($report_agg).toArray()" "federation_connection_dedup_overview"

report_agg='{"$group":{_id:"$__federation_source","total":{"$sum":1}}}'
sonarw_eval "$report_db" "db.asset_1_union.aggregate($report_agg).toArray()" "federation_asset_per_machine"
sonarw_eval "$report_db" "db.connection_1_union.aggregate($report_agg).toArray()" "federation_connection_per_machine"

# finished

echo -e "\nFinished.\n"
echo -e "Report location:"
echo -e "$report_location\n" 
echo -e "Database name:"
echo -e "$report_db\n"

exit 0
