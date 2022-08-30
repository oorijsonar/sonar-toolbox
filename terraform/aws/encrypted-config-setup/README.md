# DSF AWS Deployment with Terraform - Encrypted Config Setup

This project provides the resources to deploy the Imperva Sonar solution using terrraform.  

**Note:** This tutorial initially caters to OSX users, and has not yet been tested and documented for Windows. 

## Prerequisites and Dependencies

### **Step 1: Install required dependencies on your local system** 

1. Install [Homebrew](https://treehouse.github.io/installation-guides/mac/homebrew) on the system.
1. Install [git](https://gist.github.com/derhuerst/1b15ff4652a867391f03) using brew on the system.<br/>
    `brew install git`
1. Install [Terraform](https://www.terraform.io/) using brew on the system.<br/>
    `brew install terraform` (v0.15.1)
1. Install [awscli](https://aws.amazon.com/cli/) using brew on the system.<br/>
    `brew install awscli`
1. Download the latest by cloning this repo into the desired directory on the system. <br/>
    `git clone git@github.com:imperva/sonar-toolbox.git`

### **Step 2: Create S3 bucket and upload install package** 

1. Log in to the [AWS Management Console](https://aws.amazon.com/console/), and navigate to Service->[S3](https://s3.console.aws.amazon.com/s3/home) 
1. Click `Create Bucket` and enter the following:
    - `Bucket name` - _(required)_ globally unique name for your S3 bucket to host Sonar configs.  [See rules for bucket naming](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html).  
    *(Example: `your-company-name-sonar-configs` )*
    - `AWS Region` - _(required)_ - The AWS Region to associate the S3 bucket.  
    *(Example: `US East (Ohio) us-east-2` )*
    - `Block all public access` - _(required)_ - Public access is granted to buckets and objects through access control lists (ACLs), bucket policies, access point policies, or all.  
    **Uncheck `Block all public access`**, and manage S3 bucket access through an [AWS s3 Bucket Policy]()
    - `Bucket Versioning` - _(required)_ - Bucket versioning enabled or disabled.
    - `Default encryption` - _(required)_ - Server-side encryption enabled or disabled.
1. After creating your bucket, navigate to the Permissions tab of your bucket, and upload a bucket policy to allow access to the content from the VPC subnets.  
    **Note:** If your instance is connecting out the internet through a NAT gateway, you will need to enter the public IP address of the NAT gateway for each availability zone for your instance to gain access to the S3 bucket. 

    ```
    {
        "Version": "2012-10-17",
        "Id": "your_bucket_policy",
        "Statement": [
            {
                "Sid": "VPCAllow",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::your-bucket-name-here",
                    "arn:aws:s3:::your-bucket-name-here/*"
                ],
                "Condition": {
                    "IpAddress": {
                        "aws:SourceIp": [
                            "1.2.3.0/24",
                            "3.4.5.6/32",
                            "3.4.5.7/32",
                            "3.4.5.8/32"
                        ]
                    }
                }
            }
        ]
    }
    ```

## Step 3: Configuration and Deployment  

### Configuration Options: 

- `region` - _(required)_ - AWS Region. Valid values: `us-east-2`, `us-west-1`, etc.  
Refer to [Managing AWS Regions](https://docs.aws.amazon.com/general/latest/gr/rande-manage.html) and [AWS service endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html#region-names-codes) for examples.

- `key_pair` - _(required)_ - Name of the key pair for the EC2 instance, and used when connecting via SSH.  
  Example: `your-key-name`  

- `vpc_id` - _(required)_ - The unique id of the VPC to deploy Sonar in (referenced when creating the security group for the Sonar EC2 instance).  
  Example: `vpc-12345abcde`  

- `subnet_id` - _(required)_ - The unique id of the subnet to connect the Sonar EC2 instance to.  
  Example: `subnet-12345abcde`

- `availability_zone` - _(required)_ - [Availability Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#concepts-availability-zones) are multiple, isolated locations within each Region.  
  Example: `us-east-2a`  

- `s3_bucket` - _(required)_ - Name of the [Amazon Simple Storage Service (S3) bucket](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html) storing the Sonar install and config files. Example: `your-company-name-sonar-configs`  

- `sonar_version` - _(required)_ - Version of Sonar.  
  Example: `4.3.a`  

- `sonar_install_file` - _(required)_ - Name of the Sonar install package file.  
  Example: `jsonar-4.3.a.tar.gz`  

- `sonar_config_file` - _(required)_  - Name of the encrypted setup file.  
  Example: `dcap_setup_file"`  
  #### **Note:**  If you do not have a setup file, see `Generate Setup File` section below.

- `sonar_config_file_password` - _(required)_ -  Password for the encrypted Sonar config file.   
  Example: `SomeStrongPassword123#`  

- `sonar_image_name` - _(required)_  -  Name of the Sonar instance in [EC2](https://docs.aws.amazon.com/ec2/).
  Example: `company-region-sonar-instance` 

- `security_group_ingress` - _(required)_  - Array of IP network ranges to allow inbound access for.  
  Exposed Ports:  
    1. `8080` - HTTP SonarFinder
    1. `8443` - HTTPS SonarFinder
    1. `22` - SSH and SCP
    1. `3030` - HADR
    1. `27117` - HADR
    1. `27133` - SonarSQL API (direct db sql client access to data warehouse)  

  Example Value: `["3.4.5.6/32","1.2.3.0/16"]`   
  

### Deployment:  

In a terminal window, change directories into the the terraform folder.  
    - `cd your/path/to/sonar-toolbox/terraform`  

Next, run the following commands in this folder:  
    - `terraform init`   
    - `terraform plan`  
    - `terraform apply --auto-approve`   

  #### **Note:**  SSH to the instance, and monitor the progess of the install by tailing the following messages log:
  `tail -Fn 1000 /var/log/messages` 

#### **Generate Setup File**   

A new encrypted setup file can be obtained by performing a fresh installation, and saving the inputs from the install to a file.  

1. Accept end-user license agreement? \[yes/no\] : `yes`  

1. How would you like to enter the setup information? : `1` (Enter data manually)  

1. Enter a *concise, descriptive, and unique* Display Name for this machine. Default is the hostname : `your-sonar-hostname-here`  

1. Is this a remote machine for a federated gateway system? \[y/n\] : n   
    #### **Note:**  If you do not want a federaged deployment, enter `n` for no, and sonarw and sonarg will deploy on the same machine:

1. Please select the product you would like to install : `1` for SonarG, `2` for DCAP Central.
    #### **Note:**  Enter 2 (DCAP Central) for non-federated deployment.

1. Password for admin user : `yourpassword`  

1. Enter the password to be used for SonarW's sonargd user (ETL process). Password for sonargd : `yourpassword`  

1. Enter the password for the secAdmin user : `yourpassword`  

1. Enter the password to be used for the default SonarG user - sonarg_user (used for GUI access) : `yourpassword`  

1. Would you like to setup SonarG-Azure-Eventhub? \[y/n\] :  `enter` for default/no, or n  

1. Enter the directory to be used for sorting BSON items.  BSON sort directory defaults to `${JSONAR_DATADIR}/sonarw/tmp` : `enter` to use default.

1. Enter the directory to be used for external sorting.  External sort directory defaults to `${JSONAR_DATADIR}/sonarw/tmp` : `enter` to use default.

1. Enter the port that the server listens on when it is the master.  : `-1`
    #### **Note:**  If you do not want a federaged deployment or are deploying sonarw and sonarg on this same instance, enter `-1` to disable.  

1. Enter the System Admin email address, to be used for sending notifications : `your.admin@comnpany.com` or leave empty and `enter`  

1. Enter the From Email Address (used when sending reports via email) :  `no-reply@comnpany.com` or leave empty and `enter`

1. Enter the to Email SMTP server : `mail.company.com` or leave empty and `enter`

1. Enter the SMTP port : `25` or leave empty and `enter`

1. Enter whether to use SSL for the SMTP connection \[y/n\] : `n`

1. Enter the email account used to send emails.  SMTP user : `your.user` or leave empty and `enter`  

1. Enter the email Password.  SMTP password : `yourpassword` or leave empty and `enter`  

1. Enter the IP Address or FQN of this host.  This the public IP address or Fully Qualified host Name and is used for report links.  Public IP address:  `enter` to accept default value, or `your.hostname.here` to define your own.

1. Enter the path for reports directory.  SonarDispatcher Reports path : `${JSONAR_DATADIR}/sonarfinder/reports` : `enter` to use default.

1. Enter the path for the Sonar Kibana export directory. SonarKibana export path : `${JSONAR_DATADIR}/sonark/tmp/export` : `enter` to use default.

1. Review input before configuration.  Enter `continue` if configurations look correct.

1. Please choose one of the following options on how to proceed : `3` (Save and encrypt configuration file then exit without running)

1. Enter the full path(absolute and including filename) of the file to save the config information in.  Path : `/opt/jsonar/local/sonarg/encrypted_setup_file` : `enter` to use default.

1. Enter the password to encrypt your file.  Password : `yourpassword`  

1. Copy the file from from this instance into your S3 bucket.  