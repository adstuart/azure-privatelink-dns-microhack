# **SAP on Azure OpenHack**

# Contents

[Lab Overview](#lab-overview)

[Challenge 1 : Deploying the SAP S/4 HANA landscape](#challenge-1--deploying-the-sap-s4-hana-landscape)

[Challenge 2 : SAP parameter tuning](#challenge-2--sap-parameter-tuning)

[Challenge 3 : SAP HANA Backup using Azure native tools](#challenge-3--sap-hana-backup-using-azure-native-tools)

[Challenge 4 : Securing Fiori access from internet](#challenge-4--securing-fiori-access-from-internet)

[Challenge 5 : Setup dashboards for the SAP environment](#challenge-5--setup-dashboards-for-the-sap-environment)

[Challenge 6 : HANA Performance Validation](#challenge-6--hana-performance-validation)

[Appendix](#appendix)

# Lab Overview

Contoso group is UK based consumer electrical retail company. They had started an evaluation of moving to SAP S/4 HANA on Azure a few months ago. As part of the evaluation the IT team had setup an S/4 HANA POC landscape in Azure. Due to business reasons this was put on hold and to save costs they decided to convert these VMs to custom images and save it in Azure Shared image gallery.

With leadership changes at Contoso they have now decided to revive the POC and do a complete technical validation of the solution. You have been tasked with reinstating the environment and setup a demo how moving to Azure simplifies end to end management and operations. Key areas which the IT leadership team is looking at are

- HA solution which will give them at least 99.95% availability.
- Azure native solutions for operations like Monitoring, Backup etc.
- Zero downtime for applying changes/patches.
- Performance validation of SAP HANA
- Securing web-based access to SAP from internet using a WAF.
- Infrastructure as Code for deployment and configuration.



# Challenge 1 : Deploying the SAP S/4 HANA landscape

### Goal 


The goal of this exercise is to use the already existing image to deploy the SAP environment. Below is the High availability architecture for S/4 HANA which you need to deploy.


![S4setup image](images/s4setup.jpg)


## Task 1 : Check Shared Gallery for Images

Check that you can access the images for all the different VM types in the Shared Image gallery and note the regions in which they are available. Shared Image Gallery used is **s4hana1809.sles12**

[https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/shared-image-galleries)



## Task 2:  Deploy the SAP environment 

Deploy the SAP environment using the Terraform template [https://github.com/karthikvenkat17/sap-cluster-openhack](https://github.com/karthikvenkat17/sap-cluster-openhack). The template builds VMs from custom images in the shared image gallery **s4hana1809.sles12**

The template requires following inputs:

1. **location** - Choose one of the Azure regions where the image is available. (WestCentralUS, EastUS2, CanadaCentral, FranceCentral, WestEurope, NorthEurope)
2. **rgname** (Optional) - Name of the Resource Group to deploy resources into. This defaults to SAP-Open-Hack.
3. **sshkeypath** -  Path to your SSH public key file to be used for logging into Linux VMs. If you don't have an SSH keypair generated already, generate one as described [here](#generating-ssh-keypair) before proceeding further.
4. **adminpassword** - Password for logging in to the Windows jumpbox (remember to create a strong password)

Rest of the variable values are picked up from terraform.tfvars file automatically

**Additional information**

To start the terraform deployment, follow the steps listed below

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Clone the GitHub repository [https://github.com/karthikvenkat17/sap-cluster-openhack#](https://github.com/karthikvenkat17/sap-cluster-openhack)

`git clone https://github.com/karthikvenkat17/sap-cluster-openhack.git`


![git clone init](images/gitclone.png)

- Create a .ssh folder within the home directory and Copy the public key to a file name id_rsa.pub.
- Go to the folder sap-cluster-openhack and run

`terraform init`

This will initialize the terraform modules and download the azurerm resource provider

![terraform init](images/terraforminit.png)

- Now run apply and provide the required inputs to start the deployment.

It is possible to provide necessary inputs interactively or pass them as command line parameters.

`terraform apply`

**OR**

`terraform apply -var 'rgname=SAP-Open-hack' -var 'location=EastUS2' -var 'sshkeypath=~/.ssh/id_rsa.pub'`

![terraform apply](images/terraformapply.png)

When prompted, confirm with a **yes** to start the deployment

![terraform confirm](images/terraformconfirm.png)

- Wait for the deployment to complete. This will take approx. 10-15 minutes



## Task 3 : Explore all the deployed resources

 - Check that you can login to SAP using SAP GUI

 - Check that you can connect to HANA database using HANA Studio

 - Check the status of HANA System Replication using HANA studio

 - Check the status of all the 3 clusters (HANA, NFS and ASCS). This can be done using SSH tools using command `crm status` or using **HAWK UI**

[https://documentation.suse.com/sle-ha/15-SP1/html/SLE-HA-all/cha-conf-hawk2.html](https://documentation.suse.com/sle-ha/15-SP1/html/SLE-HA-all/cha-conf-hawk2.html)

HAWK UI requires to login as user which is part of haclient group. Command to add tstadm user to haclient group 
`usermod -a -G haclient tstadm`


### :point_right: Hint 

**Tools required for this OpenHack are already installed in the Windows Jumpbox VM, they are available either as Desktop shortcuts or in C:\Software**

**SAPGUI:** You need to create a new connection

 ![sapgui](images/sapgui.png)

**HANA Studio:** Available in **C:\Software\eclipse** , HANA database connections SYSTEMDB and SAPHANADB already created. You will need to login using the HANA Database credentials provided.

![hana studio](images/hana_studio.png)

![db logon](images/db_logon.png)

![hana db status](images/haandb.png)

For logging into the VMs you can either use **SSH Client MobaXterm** (All connections are already created) or **Putty**. You will need to **provide your SSH Private Key** to each connection.


## :checkered_flag: Results

- You have deployed an SAP S/4HANA environment using given Terraform template
- You have become familiar to components of the SAP landscape you just deployed
- You are now be able to login to the SAP system using various tools
- High availability clustering is setup correctly for NFS, HANA and Central Services
- HANA System Replication has been enabled













## Challenge 2 : SAP Parameter tuning

### Goal


The goal of this challenge is to tune SUSE operating system to SAP recommendation with minimum administrative efforts and apply changes with almost zero downtime.


## Task 1: Tune SAP parameter with minimum administrative effort

You have found that the SAP HANA VMs are not tuned as per the SAP recommendations.  Some of the recommendations in SAP note # 2382421 are not applied.  In this challenge you need to tune the parameters as per this SAP note except `net.ipv4.tcp_timestamps` which needs to be set to 0 for Azure


### :point_right: Hint


In SLES there are couple of tools available to tune the OS for running SAP namely sapconf and saptune. Sapconf performs minimum standard changes whereas saptune can apply SAP notes individually or bunch of notes relevant to the solution like SAP HANA, NetWeaver etc. You can use the customize option of saptune to edit a parameter within the note and apply it.


You will need to install saptune by running `zypper install saptune`. Since the VMs are rebuilt using the images you need re-register the repos to point to Azure SMT using the steps below before installing saptune

```suse
rm /etc/SUSEConnect
rm -f /etc/zypp/{repos,services,credentials}.d/*
rm -f /usr/lib/zypp/plugins/services/*
sed -i '/^# Added by SMT reg/,+1d'; /etc/hosts
/usr/sbin/registercloudguest --force-new
```

Useful saptune commands (For solutions substitute note with solution in the below commands)

```saptune
saptune note list
saptune note simulate <note number>
saptune note apply <note number>
saptune note customise <note number>
(opens a vi editor where the note parameters value can be customized)
```



## Task 2: Reboot VMs with least business outage 


 You need to ensure that these changes persist after reboot. Also confirm that the **HANA** failover works fine.


### :point_right: Hint 

This could be done in several ways. You will be using some of the below commands to do this task

`crm node standby <nodename>` - Make the node offline for the cluster

`crm node online <nodename>` - Make the node online for the cluster

`crm cluster stop` - Stopping the cluster service on the node where it is executed

`crm cluster start` - Starting the cluster service on the node where it is executed

`crm resource migrate <resource name>` - Migrate a resource from one node to another

`crm resource clear <resource name>` - Remove migration constraints from resources

`crm resource cleanup <resource name>` - Cleanup any previous errors in the cluster



## :checkered_flag: Results

- You have tuned the OS parameters as per SAP note easily using the right tools.
- You have tested the HANA HA setup and tested the user experience during failover.








 



# Challenge 3 : SAP HANA Backup using Azure native tools

### Goal

SAP HANA, like other database, offers the possibility to backup to files. In addition, it also offers a backup API, which allows third-party backup tools to integrate directly with SAP HANA. Products like Azure Backup service, or Commvault are using this proprietary interface to trigger SAP HANA database or redo log backups. SAP HANA offers a third possibility, HANA backup based on storage snapshots. The focus of this challenge is to configure **Azure Backup for SAP HANA**.
 


## Task 1 :  Prepare HANA VMs for Azure Backup

Contoso Group have asked you to prepare SAP HANA virtual machines for Azure Backup using BACKINT API.

You need to perform all pre-requisites and setup network connectivity to allow Azure Backup to connect to SAP HANA database as per this document.

[https://docs.microsoft.com/en-us/azure/backup/tutorial-backup-sap-hana-db](https://docs.microsoft.com/en-us/azure/backup/tutorial-backup-sap-hana-db)


### :point_right: Hint 


Your HANA database is running over a 2 node highly available cluster. For this hack **configure it only on the active node**. 

Also, you may need to register your HANA virtual machines to access SUSE repos and install package unixODBC, if not already installed.

Run following commands as root to install unixODBC

`zypper install unixODBC`

You will need to create SAP HANA HDBUSERSTORE Key named SYSTEM for user SYSTEM for password less authentication.

Run following commands as tstadm on HANA virtual machine

Syntax

`hdbuserstore -i SET <KEY> host:port <USERNAME> <PASSWORD>`

Test the connection using following command.

`hdbsql -U SYSTEM`

On the hdbsql prompt, type \s to check the status and ensure you can connect.



## Task 2 : Run backup for HANA using Azure Backup

Contoso Group have asked you to create a backup configuration to meet their requirements and to start the first backup right away.

Contoso deem it sufficient to take full backups once a week over the weekend, but want to optimize the cost and time required for backup and restore by using an optimized backup and retention policy. In the scenario where a restore becomes necessary, they want to be able to restore with no more than 20 minutes of loss of data.

Create an appropriate backup and retention policy and backup your SAP HANA database using Azure Backup.


### :point_right: Hint 

The key steps are - create a recovery services vault, configure backup, create a backup policy and backup.

[https://docs.microsoft.com/en-us/azure/backup/tutorial-backup-sap-hana-db#create-a-recovery-service-vault](https://docs.microsoft.com/en-us/azure/backup/tutorial-backup-sap-hana-db#create-a-recovery-service-vault)


## :checkered_flag: Results

- You have configured and run Azure backup for HANA database











  
# Challenge 4 : Securing Fiori access from internet

### Goal

Expose specific SAP endpoints to internet without adding public IPs to SAP VMs.


## Task : Make SAP Fiori launchpad accessible from Internet 

Contoso group wants to expose their SAP Fiori launchpad to internet. They would like to do this in a secure way without exposing any other parts of SAP.  Security team at Contoso wants proof that only Fiori launchpad can be accessed and any attempt to access other urls will result in error. 

URL for Fiori launchpad

http://hostname:port/sap/bc/ui2/flp


You can use Azure app gateway for this exercise. Below diagram explains how application gateway works. 

![App gateway image](https://docs.microsoft.com/en-us/azure/application-gateway/media/how-application-gateway-works/how-application-gateway-works.png)

### :point_right: Hint 

- You will need an additional subnet within the existing VNET (by adding a new address space) for App gateway creation
- Activate SAP ports HTTP (8000) and HTTPS (8001) using transaction SMICM.
- Note that the FQDN for SAP hostname doesn't resolve within the jumpbox. Use the IP address or just the hostname. 
- SSL is not in scope for this lab. Disable HTTPS switch for Fiori launchpad by changing the properties of service **/sap/bc/ui2/flp** in SICF. Changes need to be made in the Logon data tab and Error Pages tab (System Configuration). 
- Pay attention to NSG rules necessary for Application Gateway and your networking setup


## :checkered_flag: Results

- You have now demonstrated how SAP endpoints can be securely published to internet with the help of Azure App gateway.












# Challenge 5 : Setup dashboards for the SAP environment

### Goal 

Use Azure monitor to check performance of the SAP environment and setup dashboards.

## Task : Setup Availability and Performance dashboard for SAP 

The IT leadership team has requested for an availability and performance dashboard for the SAP environment. The dashboard must contain key performance metrics and availability for all the SAP VMs that have been deployed. 


### :point_right: Hint 


 Use Azure monitor for this exercise. Check what metrics are collected by default. There are several ways to visualize log and metric data stored in Azure Monitor
 It is sufficient to setup monitoring dashboard using **any one** of the following methods.

- Workbooks
- Azure dashboard
- PowerBI dashboard
- Grafana dashboard


[https://docs.microsoft.com/en-us/azure/azure-monitor/visualizations](https://docs.microsoft.com/en-us/azure/azure-monitor/visualizations)

See example dashboards below

![azuremonitor](images/azuremonitor.png)

![pbi](images/pbi.png)


## :checkered_flag: Results

- You now have centralized dashboards reporting performance and availability of your SAP S/4 HANA.














# Challenge 6 : HANA performance validation


### Goal

The goal of this exercise is to validate the setup of HANA infrastrcture.

## Task :  Check HANA parameters and performance 

You want to ensure that the HANA infrastructure is setup correctly and is performing as expected without involving the testing and functional teams to run tests.



### :point_right: Hint  

Use HANA mini checks SQL to verify the parameters and metrics of HANA. See SAP note # 1999993 - How-To: Interpreting SAP HANA Mini Check results

To check if infrastructure is setup correctly use HWCCT or HCMT tool. Both the tools are downloaded and available in the directory `/hana/backup/HANA_perftools` of HANA node tst-hana-vm-0

Note that some of the metrics will fail as we are using smaller VMs without write accelerators for our test deployment.




## :checkered_flag: Results

- You now successfully verified that SAP HANA system is setup correctly for optimum performance.

















# Appendix

### Generating SSH keypair

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Generate SSH keypair using the command `ssh-keygen` as shown in the screenshot below

  ![keygen](images/keygen.jpg)

- Use the public key (id_rsa.pub) for the deployment. 
- Download the private key to your desktop using the download button at the top. You will be using this file for logging into the linux VMs 


