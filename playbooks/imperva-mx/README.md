
Upload openapi to sonar
```
scp ~/imperva-mx/mx.openapi.json ${JSONAR_LOCALDIR}/action-center-souces/mx.openapi.json
```

Connect to sonarw to add new openapi source
```
new_source =   {
    "_id": "imperva_mx",
    "name": "Imperva MX API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/action-center-souces/imperva.openapi.json",
    "url": "https://mx.dev.impervademo.com"
  }
use lmrm__ae
db.action_center_sources.insert(new_source)
```

Import playbooks
// TODO

Add connection
// TODO upload spreadsheet

