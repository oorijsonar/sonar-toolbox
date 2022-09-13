
Upload openapi to sonar
```
scp ~/servicenow/servicenow.openapi.json <my sonar>:${JSONAR_LOCALDIR}/action-center-sources/servicenow.openapi.json
```

Connect to sonarw to add new openapi source
```
new_source =   {
    "_id": "servicenow",
    "name": "ServiceNow API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/action-center-sources/servicenow.openapi.json",
    "url": "http://localhost:8443"
  }
use lmrm__ae
db.action_center_sources.insert(new_source)
```

Synchronize actions
```
https://<my sonar>/playbook_synchronization_history.xhtml
```

Import playbooks
```
https://<my sonar>/playbook_drafts.xhtml
-> Click on Import Draft
-> Select the playbook you want to import
-> Click on Publish - Replace for new Version - Confirm Publish
```

Add connection
Make a copy of the `ServiceNow_template.xlsx` and add your username, password, url, and admin_email. Then upload the spreadsheet to add a new connection
```
https://<my sonar>/import_assets.xhtml
-> Select Edit Data
-> Click on Choose
-> Select the ServiceNow.xlsx file with the credentials
-> Click on Upload
-> You'll be sent to a validation screen, click on Validate All
-> Click on Run Import Assets -> Import
-> You should see a message "1 assets imported, 0 assets updated, 0 assets failed to import, 1 connections imported, 0 connections updated, 0 connections failed to import, 0 warnings from asset import, "
```

Run and test the playbook:
```
https://<my sonar>/playbooks.xhtml
-> Look for the playbook you published
-> Click on Options
-> Click on Run Advanced
-> Edit the parameters, for the asset id field use the asset_id from the spreadsheet you uploaded, default is service_now 
-> Click Run
-> Check if result is the same as expected
```

## ServiceNow playbooks

### ServiceNow CMDB Enrichment

Queries ServiceNow tables and saves data into `sonargd.servicenow_cmdb_table_data` to be used for audit data enrichment.

- Filename: `servicenow_cmdb_enrichment.json`
- Playbook Id: `service_now_cmdb_enrichment`

Tips:
- Edit `ACTION - Servicenow Query Table` to fine tune ServiceNow query
