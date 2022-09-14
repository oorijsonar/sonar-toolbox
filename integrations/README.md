# Integration Playbooks

// TODO what are playbooks

## Version compatibility

```
jsonar_4.9.openapi4
```

## Installation

// TODO summarize the installation process

### Download files

Option 1
```
$ wget -O sonar-toolbox.zip https://github.com/imperva/sonar-toolbox/archive/refs/heads/master.zip
$ unzip sonar-toolbox.zip
$ cd sonar-toolbox-master/integrations/
```

Option 2
```
$ git clone https://github.com/imperva/sonar-toolbox.git
$ cd sonar-toolbox/integrations/
```

### OpenAPI sources

// TODO what are OpenAPI sources?

The suggested location for the openapi files are in `${JSONAR_LOCALDIR}/openapi-sources`. 

Copy files to the warehouse
```
$ scp -r openapi <warehouse>:${JSONAR_LOCALDIR}/openapi-sources
```

Move the uploaded file to the suggested location:
```
$ ssh ec2-user@<warehouse>
$ sudo su
$ . /etc/sysconfig/jsonar
$ cd $JSONAR_LOCALDIR
$ mv ~ec2-user/openapi-sources .
$ chown -R sonarw:sonar openapi-sources
```

Connect to sonarw in the warehouse shell:
```
$ CERT_AS_PASSWD=$(awk -vORS="\\\n" "1" ${JSONAR_LOCALDIR}/ssl/client/admin/cert.pem)
$ ${JSONAR_BASEDIR}/bin/mongo --port 27117 --authenticationMechanism PLAIN --authenticationDatabase "\$external" -u"CN=admin" -p"${CERT_AS_PASSWD}"
```

Add new source to sonarw:
note: this is a list of all available openapi sources, you can pick and choose in case you don't want to add them all. Refer to `Depends on` section in [Playbooks](#playbooks) -> the playbook you intend to use.
```
> var new_sources = []
> new_sources.push({
    "_id": "imperva_mx",
    "name": "Imperva MX API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/openapi-sources/imperva-mx.openapi.json",
    "url": "https://unused-placeholder.com"
  })
> new_sources.push({
    "_id": "servicenow",
    "name": "ServiceNow API",
    "type": "OFFLINE",
    "disabled": false,
    "openapi": "file://${JSONAR_LOCALDIR}/openapi-sources/servicenow.openapi.json",
    "url": "http://unused-placeholder.com"
  })
> use lmrm__ae
> db.action_center_sources.insertMany(new_sources)
```

Synchronize actions
```
Warehouse Home Page -> Playbooks -> Synchronization History -> Synchronize Now
OR
https://<warehouse>/playbook_synchronization_history.xhtml
```

## Usage

### Adding a connection

// TODO how to add a connection

### Importing a playbook

// TODO how to import playbook with screenshots

## Playbooks

### ServiceNow CMDB

// TODO explain use case and playbooks, add screenshots

#### 1 - Import ServiceNow CMDB data

// TODO description + images

Filename: [1_import_servicenow_cmdb_data.json](playbook/ServiceNow_CMDB/1_import_servicenow_cmdb_data.json)

Playbook Id: `import_servicenow_cmdb_data`

Depends on:
- ServiceNow openapi source - [servicenow.openapi.json](openapi/servicenow.openapi.json)
- ServiceNow connection - [ServiceNow_template.xlsx](template/ServiceNow_template.xlsx)

#### 2 - Push CMDB data to MX

// TODO description + images

Filename: [2_push_cmdb_data_to_mx.json](playbook/ServiceNow_CMDB/2_push_cmdb_data_to_mx.json)

Playbook Id: `push_cmdb_data_to_mx`

Depends on:
- Imperva MX openapi source [imperva-mx.openapi.json](openapi/imperva-mx.openapi.json)
- Imperva MX connection [ImpervaMX_template.xlsx](#template/ImpervaMX_template.xlsx)

#### 3 - CMDB ServiceNow to MX integration

// TODO description + images

Filename: [3_cmdb_servicenow_to_mx_integration.json](playbook/ServiceNow_CMDB/3_cmdb_servicenow_to_mx_integration.json)

Playbook Id: `cmdb_servicenow_to_mx_integration

Depends on:
- [Import ServiceNow CMDB data](#1---import_servicenow_cmdb_data)
- [Push CMDB data to MX](#2---push_cmdb_data_to_mx)

## FAQ

// TODO FAQ

## Contributing

Would you like to contribute to this project? [CONTRIBUTING.md] has all the details on how to do that.

[CONTRIBUTING.md]: CONTRIBUTING.md

## License

Imperva Playbooks are released under the [MIT License](http://www.opensource.org/licenses/MIT).
