terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  region = var.region
}

data "template_cloudinit_config" "sonar_config" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    filename     = "sonar-init.sh"
    content  = <<-END
        #!/bin/bash
        sudo su
        hostname ${var.sonar_image_name}

        sudo yum install epel-release -y
        sudo yum install jq -y
        sudo yum install lvm2 -y

        sudo mkdir -p /opt/
        sudo pvcreate -ff /dev/nvme1n1 -y
        sudo vgcreate data /dev/nvme1n1 
        sudo lvcreate -n vol0 -l 100%FREE data -y
        sudo mkfs.xfs /dev/mapper/data-vol0
        echo "$(blkid /dev/mapper/data-vol0 | cut -d ':' -f2 | awk '{print $1}') /opt xfs defaults 0 0" | sudo tee -a /etc/fstab
        sudo mount -a

        sudo groupadd sonar
        sudo useradd -g sonar sonarw 
        sudo useradd -g sonar sonargd        

        curl -k https://${var.s3_bucket}.s3.${var.region}.amazonaws.com/${var.sonar_install_file} -o /tmp/${var.sonar_install_file}
        
        sudo tar -xzvf /tmp/${var.sonar_install_file} -C /opt
        
        sudo /opt/jsonar/apps/${var.sonar_version}/bin/python3 /opt/jsonar/apps/${var.sonar_version}/bin/sonarg-setup --no-interactive --accept-eula --newadmin-pass="${var.admin-pass}" --secadmin-pass="${var.secadmin-pass}" --sonarg-pass="${var.sonarg-pass}" --sonargd-pass="${var.sonargd-pass}"
    END
  }
}

data "aws_ami" "SONAR_INSTANCE" {
    owners = ["aws-marketplace"]
    filter {
        name = "name"
        values = ["ca036d10-2e28-4b60-ba48-61e66b8e29a8.0f79e08e-623c-448a-aaf8-01980c58858a.DC0001"]
    }
}

resource "aws_instance" "sonarw" {
    ami = data.aws_ami.SONAR_INSTANCE.id
    instance_type = "c5.4xlarge"
    tags = {
        Name = var.sonar_image_name
    }
    key_name = var.key_pair
    subnet_id = var.subnet_id
    associate_public_ip_address = false
    user_data = data.template_cloudinit_config.sonar_config.rendered
    disable_api_termination = false
    ebs_optimized = false
    monitoring = false
    credit_specification {
        cpu_credits = "standard"
    }
    vpc_security_group_ids = [aws_security_group.allow_sonar.id]
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.ebs_vol.id
  instance_id = aws_instance.sonarw.id
}

resource "aws_ebs_volume" "ebs_vol" {
  availability_zone = var.availability_zone
  size              = 100
}

resource "aws_security_group" "allow_sonar" {
    name = "Allow Sonar Access"
    vpc_id = var.vpc_id
    ingress {
        from_port = 8080
        protocol = "TCP"
        to_port = 8443
        cidr_blocks = var.security_group_ingress
    }
    ingress {
        from_port = 8443
        protocol = "TCP"
        to_port = 8443
        cidr_blocks = var.security_group_ingress
    }
    ingress {
        from_port = 22
        protocol = "TCP"
        to_port = 22
        cidr_blocks = var.security_group_ingress
    }
    ingress {
        from_port = 3030
        protocol = "TCP"
        to_port = 3030
        cidr_blocks = var.security_group_ingress
    }
    ingress {
        from_port = 27117
        protocol = "TCP"
        to_port = 27117
        cidr_blocks = var.security_group_ingress
    }
    ingress {
        from_port = 27133
        protocol = "TCP"
        to_port = 27133
        cidr_blocks = var.security_group_ingress
    }
    egress {
        from_port = 0
        protocol = "-1"
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }
}
