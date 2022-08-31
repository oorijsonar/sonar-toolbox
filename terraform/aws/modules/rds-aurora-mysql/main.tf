terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  region = var.region
}

resource "aws_db_subnet_group" "rds_db_sg" {
  name       = "${var.cluster_identifier}-db-subnet-group"
  subnet_ids = var.rds_subnet_ids
  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_rds_cluster_parameter_group" "impv_rds_db_pg" {
  name        = "${var.cluster_identifier}-pg"
  family      = "aurora-mysql5.7"
  description = "RDS default cluster parameter group"
  parameter {
    name  = "server_audit_logging"
    value = 1
  }
  parameter {
    name  = "server_audit_excl_users"
    value = "rdsadmin"
  }
  parameter {
    name  = "server_audit_events"
    value = "CONNECT,QUERY,QUERY_DCL,QUERY_DDL,QUERY_DML,TABLE"
  }
}

resource "aws_rds_cluster" "rds_db" {
  depends_on                        = [aws_rds_cluster_parameter_group.impv_rds_db_pg,aws_db_subnet_group.rds_db_sg]
  db_subnet_group_name              = aws_db_subnet_group.rds_db_sg.name
  cluster_identifier                = var.cluster_identifier
  engine                            = "aurora-mysql"
  master_username                   = var.master_username
  master_password                   = var.master_password
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.impv_rds_db_pg.name
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  skip_final_snapshot  = true
}

resource "aws_cloudwatch_log_group" "audit" {
  name = "/aws/rds/cluster/${aws_rds_cluster.rds_db.cluster_identifier}/audit"
}
resource "aws_cloudwatch_log_group" "error" {
  name = "/aws/rds/cluster/${aws_rds_cluster.rds_db.cluster_identifier}/error"
}
resource "aws_cloudwatch_log_group" "general" {
  name = "/aws/rds/cluster/${aws_rds_cluster.rds_db.cluster_identifier}/general"
}
resource "aws_cloudwatch_log_group" "slowquery" {
  name = "/aws/rds/cluster/${aws_rds_cluster.rds_db.cluster_identifier}/slowquery"
}

locals {
  gw_uuid = "3f96e3bd-8471-47e1-bce0-364f6005bdc3"
  hub_uuid = "c84612ed-57ba-49d2-9cdf-6a1ef2c5f966"
  rds_asset_json  = {
    "import": { 
      "documents_to_import": [
        {
          "asset_id": aws_rds_cluster.rds_db.arn,
          "asset_display_name": aws_rds_cluster.rds_db.cluster_identifier,
          "Server Type": "AWS RDS AURORA MYSQL CLUSTER",
          "Server IP": aws_rds_cluster.rds_db.arn,
          "Server Port": aws_rds_cluster.rds_db.port,
          "Server Host Name": aws_rds_cluster.rds_db.endpoint,
          "arn": aws_rds_cluster.rds_db.arn,
          "auth_mechanism": "password",
          "username": var.master_username,
          "password": var.master_password,
          "reason": "sonargateway",
          "database_name": aws_rds_cluster.rds_db.cluster_identifier,
          "admin_email": "admin@imperva.com",
          "jsonar_uid": var.gw1_uuid,
          "jsonar_uid_display_name": var.gw1_display_name
        }
      ] 
    }
  }
  log_group_json  = {
    "root": { 
      "run_type" : "direct", 
      "documents_to_import": [
        {
          "asset_id": aws_cloudwatch_log_group.audit.arn,
          "parent_asset_id": aws_rds_cluster.rds_db.arn,
          "asset_display_name": aws_cloudwatch_log_group.audit.name,
          "Server Type": "AWS LOG GROUP",
          "Server IP": "${aws_cloudwatch_log_group.audit.arn}:*",
          "Server Host Name": aws_rds_cluster.rds_db.endpoint,
          "arn": aws_cloudwatch_log_group.audit.arn,
          "region": var.region,
          "location": var.region,
          "Server Port": aws_rds_cluster.rds_db.port,
          "auth_mechanism": "default",
          "content_type": "AWS RDS AURORA MYSQL",
          "admin_email": "admin@imperva.com",
          "jsonar_uid": var.gw1_uuid,
          "jsonar_uid_display_name": var.gw1_display_name
        }
      ] 
    }
  }
}


# Connect to hub with key_pair_pem, and call DSF API invoking invoke import_assets_api playbook to import the rds asset with the rds_asset_json above
resource "null_resource" "remote_exec_rds_asset" {
  depends_on = [aws_rds_cluster.rds_db]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file(var.key_pair_pem_local_path)
    host     = var.hub_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -X POST --cacert /opt/jsonar/local/ssl/ca/ca.cert.pem --key /opt/jsonar/local/ssl/client/admin/key.pem --cert /opt/jsonar/local/ssl/client/admin/cert.pem -H 'Content-Type: application/json' -X POST https://localhost:27989/playbook-engine/playbooks/import_assets_api/run?synchronous=true -d '${jsonencode(local.rds_asset_json)}'"
      # "curl -k -H \"Authorization: Bearer your-bearer-token\" -H \"Content-Type: application/json\" -X POST https://172.20.0.250:8443/api/playbook-runner/playbook-engine/playbooks/import_discover_connect_gateway/run?synchronous=true -d '${jsonencode(local.register_json)}'"
    ]
  }
}

# Connect to hub with key_pair_pem, and call DSF API invoking import_discover_connect_gateway playbook to import the rds log group with the log_group_json above
resource "null_resource" "remote_exec_log_group" {
  depends_on = [aws_rds_cluster.rds_db,null_resource.remote_exec_rds_asset]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file(var.key_pair_pem_local_path)
    host     = var.hub_ip
  }

  provisioner "remote-exec" {
    inline = [
      "curl -X POST --cacert /opt/jsonar/local/ssl/ca/ca.cert.pem --key /opt/jsonar/local/ssl/client/admin/key.pem --cert /opt/jsonar/local/ssl/client/admin/cert.pem -H 'Content-Type: application/json' -X POST https://localhost:27989/playbook-engine/playbooks/import_discover_connect_gateway/run?synchronous=true -d '${jsonencode(local.log_group_json)}'"
      # "curl -k -H \"Authorization: Bearer your-bearer-token\" -H \"Content-Type: application/json\" -X POST https://172.20.0.250:8443/api/playbook-runner/playbook-engine/playbooks/import_assets_api/run?synchronous=true -d '${jsonencode(local.log_group)}'"
    ]
  }
}

