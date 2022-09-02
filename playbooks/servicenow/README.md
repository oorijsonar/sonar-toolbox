
Upload openapi to sonar
```
scp ~/servicenow/servicenow.openapi.json ${JSONAR_LOCALDIR}/action-center-souces/servicenow.openapi.json
```

Connect to sonarw to add new openapi source
```
new_source =   {
    "_id": "servicenow",
    "name": "ServiceNow API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/action-center-souces/servicenow.openapi.json",
    "url": "http://localhost:8443"
  }
use lmrm__ae
db.action_center_sources.insert(new_source)
```

Import playbooks
//TODO

Add connection
// TODO upload spreadsheet

