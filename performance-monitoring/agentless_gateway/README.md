# Agentless Gateway performance monitoring for Data Security Fabric (DSF)

The performance monitoring package for DSF Agentless Gateway appliances outputs performance metrics in json format locally pushed into the DSF Hub.

## Getting Started

Download the latest files from the performance-monitoring/agentless_gateway folder.  Within this folder are 5 required files:

1. Download and copy the following files into the `/tmp` directory on the Agentless Gateway:  
    - `imperva_perf_stats.conf`  
    - `imperva_perf_stats.json`  
    - `get_system_stats.py`  
    - `sonargetstats.service`  
    - `sonargetstats.timer`  
    
### Setting up the syslog listener ###
1. Setting up the TCP syslog listener  
   Set up the listener and mapping to receive performance monitoring syslog events from DAM MXs, Agent gateways and for the agentless gateway to push performance data locally into the `sonargd.imperva_perf_stats_stats` collection.
    - SSH to the Agentless Gateway, and move each file to specified directory outlined below.  
      >`mv /tmp/imperva_perf_stats.conf ${JSONAR_BASEDIR}/bin/imperva_perf_stats.conf`  
      >`chmod +x ${JSONAR_BASEDIR}/bin/imperva_perf_stats.conf`  
      >`mv /tmp/imperva_perf_stats.json /opt/jsonar/apps/4.x.x/etc/sonar/gateway/imperva_perf_stats.json`  
    - Restart the `sonarrsyslog` service to load the new configuration:  
      >`sudo systemctl restart sonarrsyslog`  

    - Validate the Agentless Gateway is listening on port `10667`
      >`netstat -na | grep 10667`  
      
      Successful output:  
      >`]# netstat -na | grep 10667`  
      `tcp  0 0 0.0.0.0:10667  0.0.0.0:* LISTEN`  
      `tcp6 0 0 :::10667 :::* LISTEN`  

1. Create the `soargd.imperva_perf_stats`collection on the Hub  
    - SSH into the Hub/Warehouose, and export environment variables:
        >`export $(cat /etc/sysconfig/jsonar)`
    - Log into Mongo, and create the `soargd.imperva_perf_stats` collection on the warehouse:
        >`${JSONAR_BASEDIR}/bin/mongo --port 27117  -u admin -p`  
        [enter sonar admin password when prompted]  
        >`use sonargd`  
        >`db.createCollection("imperva_perf_stats")`      

1. Setting up Agentless Gateway performance monitoring:
    - SSH into the Hub/Warehouose, and watch the incoming folder monitoring for new incoming warehouse part files:  
        >`watch -d "ls /opt/jsonar/data/sonargd/incoming/ | grep perf"`
    
    - In a separate terminal, SSH into the Agentless Gateway and export environment variables:
        >`export $(cat /etc/sysconfig/jsonar)`    
    - Set up the script/scheduled job to collect and push perfomenace monitoring data to the local listener into the warehouse.
        >`mv /tmp/get_system_stats.py ${JSONAR_BASEDIR}/bin/get_server_stats.py`  
        >`mv /tmp/sonargetstats.service /etc/systemd/system/sonargetstats.service`  
        >`mv /tmp/sonargetstats.timer /etc/systemd/system/sonargetstats.timer`  
        >`systemctl enable sonargetstats.timer`  
        >`systemctl start sonargetstats.timer`  
    - Made script executable:
        >`chmod +x ${JSONAR_BASEDIR}/bin/get_server_stats.py`  
    - Create test event on the Agentless Gateway
        >`systemctl start sonargetstats.service`  
    - Monitor the outgoing folder on the gateway to watch for outgoing events:
        >`watch -d "ls ${JSONAR_DATADIR}/sonargd/outgoing"`

    - Once you see data transfered from the gateway outgoing folder, to incoming folder on the warehouse, use the analyze app to fiew the contents of sonargd.