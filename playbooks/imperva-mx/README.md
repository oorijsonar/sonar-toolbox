
Upload openapi to sonar
```
scp ~/imperva-mx/mx.openapi.json ${JSONAR_LOCALDIR}/action-center-sources/mx.openapi.json
```

Connect to sonarw to add new openapi source
```
new_source =   {
    "_id": "imperva_mx",
    "name": "Imperva MX API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/action-center-sources/imperva-mx.openapi.json",
    "url": "https://mx.dev.impervademo.com"
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
-> Click on Publish
```

Add connection
Make a copy of the `MX_template.xlsx` and add your username, password, url, and admin_email. Then upload the spreadsheet to add a new connection
```
https://<my sonar>/import_assets.xhtml
-> Select Edit Data
-> Click on Choose
-> Select the MX.xlsx file with the credentials
-> Click on Upload
-> You'll be sent to a validation screen, click on Validate All
-> Click on Run Import Assets -> Import
-> You should see a message like this (for 1 uploaded row): "1 assets imported, 0 assets updated, 0 assets failed to import, 1 connections imported, 0 connections updated, 0 connections failed to import, 0 warnings from asset import, "
```

Run and test the playbook:
```
https://<my sonar>/playbooks.xhtml
-> Look for the playbook you published
-> Click on Options
-> Click on Run Advanced
-> Edit the parameters, for the asset id field use the asset_id from the spreadsheet you uploaded 
-> Click Run
-> Check if result is the same as expected
```

## ServiceNow playbooks

### ServiceNow CMDB to MX Dataset

// TODO

- Filename: `servicenow_cmdb_to_MX_dataset.json`
- Playbook Id: `service_now_to_mx_dataset`

## Send ServiceNow CMDB Data to MX

// TODO 

- Filename: `servicenow_collection_to_MX.json`
- Playbook Id: `service_now_collection_to_mx`
