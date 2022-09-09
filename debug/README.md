# Debug Tools

## Federation Report

Copy `federation_report.sh` to `$JSONAR_LOCALDIR/../debug/federation_report.sh` and change file permissions
```
$ . /etc/sysconfig/jsonar
$ mkdir $JSONAR_LOCALDIR/../debug
$ mv /tmp/federation_report.sh $JSONAR_LOCALDIR/../debug/
$ chown -R sonarw:sonar $JSONAR_LOCALDIR/../debug
$ chmod 744 $JSONAR_LOCALDIR/../debug/federation_report.sh
```

To execute the report run:
```
$ sudo su sonarw
$ . /etc/sysconfig/jsonar
$ cd $JSONAR_LOCALDIR/../debug
$ ./federation_report.sh
```

# What to do with the results?

To recreate the asset and collection collections find any document on `<coll>_2_dedup` with field `pick:conflict` and replace it with the correct document. To find the conflicts run:
```
> use federation_report_<timestamp>
> db.<coll>_2_dedup.find({"pick":"conflict"})
```

To fix conflicts run:
```
> use federation_report_<timestamp>
> db.<coll>_2_dedup.aggregate({"$match":{"_id":"<_id>"}},{"$project":{"*":1,"pick":{"$arrayElemAt":["$set",<array index>]}}},{"$out":{"name":"<coll>_3_final","append":true}})
```

After fixing all the conflicts run this to recreate the collection:
```
> use federation_report_<timestamp>
> db.<coll>_3_final.aggregate({"$replaceRoot":{"newRoot":"$pick"}},{"$out":"<coll>"})
```


# What does the script do? - WIP
- Check if all the agentless gateways are accessible
- Check status of export jobs for assets, connections, and mapping
- Check if sonargd.conf has the correct information
- Check the outgoing and incoming folders for left over exported asset and connection files
- Run stats on asset and connection for every gateway
- Pull information about assets and connections from every gateway and save it in a backup collection dedup_bkp_asset_gw1/dedup_bkp_connection_gw1
- Consolidate assets and connections from the gateways and warehouse. This will be done based on the asset_id and _id fields (we can change that on the fly if we decide to use other fields). One document will be generated for every asset_id/_id tuple and save in a new collection (dedup_asset dedup_connection) with the conflicting fields in an array field per doc.

