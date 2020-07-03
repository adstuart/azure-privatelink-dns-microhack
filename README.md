# **Azure Private Link DNS MicroHack**

# Contents //update this last//

[Lab Overview and Pre-req](#lab-overview)

[Challenge 1 : Connect to Azure SQL](#challenge-1--deploying-the-sap-s4-hana-landscape)

[Challenge 2 : Deploy service endpoints](#challenge-2--sap-parameter-tuning)

[Challenge 3 : Deploy private endpoint for SQL](#challenge-3--sap-hana-backup-using-azure-native-tools)

[Challenge 4 : Implement Azure DNS Private Zones integration](#challenge-4--securing-fiori-access-from-internet)

[Challenge 5 : Implement custom DNS integration (Windows DNS on Windows Server 2019)](#challenge-5--setup-dashboards-for-the-sap-environment)

[Challenge 6 : Implement On-Premises access using conditional forwarding](#challenge-6--hana-performance-validation)

[Challenge 7 : Optional, hard! Implement On-Premises access within using existing Azure hosted custom DNS server](#challenge-6--hana-performance-validation)

[Appendix](#appendix)

# Scenario

Contoso group is a consumer electrical retail company. The company works within a regulated industry and would like to secure their use of Azure PaaS services. As part of the evaluation the IT team has started to look at using **Azure Private Link**. 

## Context

This MicroHack scenario walks through the use of Azure Private Link with a focus on the required changes needed for DNS. Specifically this builds up to include working with a an existing custom DNS infrastrucutre (I.e. a customer using their own Virtual Machines for Internal DNS Resolution). In this lab we use Microsoft DNS running on top of Microsoft Windows Server 2019, but your customer could be using another DNS solution such as BIND on Linux, or Infoblox.

# Pre-requisites

## Overview

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.

With these pre-requisites in place, we can focus on building the differentiated knowledge in Private Link that is required when working with the product, rather than spending hours repeating simple tasks such as setting up Virtual Networks and Virtual Machines. 

At the end of this seciton your base lab build looks as follows:

![image](images/base.png)

In summary:

- "On-Premises" environment simulated by Azure Virtual Network
- On-Premises contains a client VM and a DNS Server VM
- On-Premises is connected to Azure via a Site-to-Site VPN
- Azure contains a simple Hub and Spoke topology, with a client VM and DNS Server VM

## Task 1 : Deploy Template

We are going to use Terraform to deploy the base environment. It will be deployed in to your subscripiton, with resources running in the Azure West Europe region.

To start the terraform deployment, follow the steps listed below:

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Clone the following GitHub repository 

`git clone https://github.com/carlsyner/privatelink-dns-microhack.git`

- Go to the new folder ./privatelink-dns-microhack and initialize the terraform modules and download the azurerm resource provider

`terraform init`

- Now run apply to start the deployment (When prompted, confirm with a **yes** to start the deployment)

`terraform apply`

- Choose a suitable password to be used for your Virtual Machines

- Wait for the deployment to complete. This will take around 30 minutes (the VPN gateways take a while).

## Task 2 : Explore and verify the deployed resources

- Verify you can access the On-Premises Virtual Machine via RDP to the Public IP using the following credentials

Username: AzureAdmin

Password: <see step above>

- Verify that you are able to hop from the jumpbox to all Virtual Machines, using their Private IP addresses and RDP access. This step also proves that the Site-to-site VPN is online. 

### :point_right: Hint 

**Desktop shortcuts exist for easy RDP access to other virtual machines**

## :checkered_flag: Results

- You have deployed a basic Azure and On-Premises environment using a Terraform template
- You have become familiar with the components you have deployed in your subscripiton
- You are now be able to login to all VMs using the supplied credentials
- On-Premises VMs can contact Azure VMs

Now that we have the base lab deployed, we can progress to the Private Link challenges!

# Challenge 1 : Connect to Azure SQL

### Goal 

The goal of this exercise is to deploy a simple Azure SQL Sever and observe the default network behaviour when connecting to it. 

## Task 1 : Deploy an Azure SQL Server

Within the resource group named private-link-microhack-hub-rg, deploy a simple Azure SQL Server in the West Europe. Example config shown below.

![image](images/1.PNG)

How do we connect to this database by default, what networking information is needed, where do we find this?

## Task 2:  Test default connectivity to Azure SQL

Using the FQDN obtained in the previous step, confirm that your Azure Management Client VM can establish a connection to your SQL Server. Launch SQL Server Management Studio (SSMS) and input your SQL Server details and credentials.

![image](images/2a.png)

- Why does this connection fail?

## Task 2:  Modify SQL server firewall

- What settings on the Azure SQL server firewall do you need to modify?

- How can you verify which source Public IP address your Azure Management Client VM is using when accessing the Internet?

- How can you verify which destination Public IP is being used when connecting to your SQL Server FQDN?

![image](images/2.PNG)

## :checkered_flag: Results

- You have deployed a basic Azure SQL Server and connected to it from your Azure client VM. You have confirmed that you are accessing it via the "Internet" (This traffic does not leave the Microsoft backbone, but it does use Public IP addresses). The traffic is sourced from the dynamic NAT address on your client VM, and is destined to a public IP address sitting in front of the Azure SQL Service. 

# Challenge 2 : Implement Service Endpoints to restrict access to your Azure SQL Server

### Goal

The goal of this challenge is to implement Service Endpoints to restrict access to your Azure SQL Server; turning off inbound connections from Public IPs (The Internet) and only allowing access from the subnet within which your Azure Client VM Resides.

## Task 1: Remove public IP address from SQL Server firewall

Within the previous step we added the public NAT IP address used by our client VM to the SQL Server firewall. Please remove this IP address and save the firewall settings. This ensure that no inbound connecitons are permitted from any public IP address.

## Task 2: Enable Service Endpoints on your subnet

On your Infra subnet, within the Azure Spoke VNet, enable Service Endpoints for Azure.SQL. 

![image](images/3.PNG)

## Task 3: Enable Virtual Network access within SQL Server Firewall

Create a new Virtual Network rule within your SQL Server Firewall allowing access from the InfrastructureSubnet within which your Azure Client VM resides. Notice how it recognises that you have enabled the service endpoint for Azure.SQL in Task 1 - "service endpoint status = enabled".

![image](images/4.PNG)

## :checkered_flag: Results

- Your SQL Server is no longer accepting connections from any Public IP address. It only accepts connections from your specific Subnet where service endpoints are enabled. Verify that you are still able to connect to your server via SSMS.

### :point_right: Hint 

**Even with service endpoints enabled, we are still sending destination traffic to the Public Interface of our SQL Server. The difference is how the traffic is sourced; now utilisaiton a special "VNET:Subnet" tag, rather than the Public IP address in Step 1**

# Challenge 3 : Deny public access to Azure SQL Server

### Goal

In this step we will block all inbound access to your SQL Server on its public interface. This means that any existing Firewall rules (Public IP or Virtual Network) will fail to work. This will then create our requirement to peform challenge 4; the use of Private Endpoints for connectivity.

Furhter reading on this step

https://docs.microsoft.com/en-us/azure/azure-sql/database/connectivity-settings#deny-public-network-access
 
## Task 1 :  Turn off Public access

![image](images/5.PNG)

## :checkered_flag: Results

- You have blocked all public access, verify that your Virtual Machine is no longer able to access via SSMS.

# Challenge 4 : Deploy a Private Endpoint to utilise Azure Private Link for access to Azure SQL

### Goal

In order to access your SQL Server via its "Private interface" we need to setup a new Private Endpoint and map this to your specific server. This will allow us to access the SQL server from your client VM, whilst retaining the use of "deny public access".

## Task 1 : Setup Private Endpoint

- Search for Private Link in the portal and click on "create private endpoint".
- Use your spoke resource-group and give it a name such as PE-SQL
- Within step 2 "resource" we choose which PaaS service we want to point our Private Endpoint at. Look within your directory to find your SQL Server (use resource type microsoft.sql/servers and sub-resource sqlServer)
- Within step 3 "configuration" we choose where to place your Private Endpoint NIC. Place it within the same InfrastructureSubnet as your VM, this will be the default. 
- Leave the Private DNS Integration at the default "yes". More on this later.

![image](images/6.PNG)

## Task 2: Observe deployed resources and functions

Once deployed you now have some new resources in your spoke resource group:

- A **Private Endpoint** named something like PE-SQL. Notice how it obtains an IP dynamically (10.1.0.5). Also notice how it has been auto-approved on the provider side (this happened because you have the appropriate RBAC rights on the SQL Server). If you did not, for example the SQL server you were trying to connect to was within another Azure AD tenant, the servie owner would approve conneciton on their side.
- An **Azure DNS Private Zone** for privatelink.database.windows.net. This was automatically created for you as part of the portal experience for Private Endpoints. Have a look within this resource and notice how you have an A record mapping your PE IP of 10.1.0.5 to your SQL Server FQDN. Click on Virtual Network Links and also observe how this zone is linked to your spoke-vnet.

## Task 3: Test private connectivity via your Private Endpoint

Back on your Client VM, re-run the nslookup command you used earlier to check what IP address is being used by your SQL server. Notice how the DNS lookup now returns a Private IP address, and not a Public IP.

![image](images/7.PNG)

Re-connect using SSMS and ensure access is working again.

## :checkered_flag: Results

- You have connected to your SQL server via a new Private Endpoint
- Your SSMS conneciton is still using the same FQDN <database-name>.database.windows.net, no client changes were required. However your Azure DNS Private Zone is defined for <database-name>.**privateliink**.database.windows.net. How is this re-direct happening? Pay close attention to the output of your nslookup command earlier.
 - Notice how an Azure DNS Private Zone was deployed for you, and automatically setup with the correct A record and VNet link. Would the same thing happen if using AZ CLI or Powershell to deploy your Private Endpoint? If not, what would be required?
 
# Challenge 5 : Work with a custom DNS server inside of Azure

### Goal 

In the previous challenge we successfully used Azure Private Link and Azure DNS Private Zones to connect in a secure way to our SQL server. This worked great as we were able to link our Azure DNS Private Zone direct to the spoke Virtual Network. The Spoke Virtual network has the default DNS settings; sending all DNS requests by default to Azure DNS via the special 168.63.129.16 address. More on that here https://docs.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16. 

However the previous challenge was not reflective of a real world configuration for lots of customers. Many Azure network designs use a custom DNS solution such as customer manged DNS running on top of an IaaS Virtual Machine (or pair of VMs) hosted in the Azure VNet. In this challenge we will alter our Spoke VNet to utilise our custom DNS server inside of the Azure VNet; a Windows Server 2019 VM running Microsoft DNS. We will also ensure we retain access to our SQL Server and that the DNS response continues to include the use of our Private Endpoint IP address.

## Task 1 : Change Spoke VNet DNS settings

Update the Spoke VNet custom DNS settings to point at your DNS Server VM inside of the Hub VNet. In a production deployment this would typicaly consist of a pair of VMs, for our lab we only have a single VM.

![image](images/8.PNG)

Reboot your Azure client VM so that it picks up the new DNS settings.

Re-run your nslookup command to check the IP address returned for your SQL database. Notice how the DNS server used is now 10.0.0.4, but the A record returned has not regressed to using the public VIP of SQL. Access will not work in this configuration as you are not utilising your Private Endpoint.

![image](images/9.PNG)

Why has this happened if your Azure DNS private zone is still in place?

## Task 2 : Modify Azure DNS Private Zone

Your Azure DNS Private Zone is only linked to your Spoke VNet. However, your Spoke VNet is now sending its requests for DNS to the DNS Server inside of your Hub VNet. This in turn is configured to query Azure DNS. As your Azure DNS Private Zone is not linked to your Hub VNet, requests from this VNet utilise only the records held within the Public Zones. Lets change that by swinging the Virtual Network link over from your Spoke VNet, to your Hub VNet.

![image](images/10.PNG)

## Task 3 : Add conditional forwarder to DNS Server VM in Azure

Your custom DNS server inside of Azure consists of a standard Windows Server 2019 VM, with the DNS role enabled. The default configuration of this is to send all unknown DNS requests to something called Root Hints (A known collection of servers on the Internet that can be used for public DNS lookups). You can veirfy this via logging in to the VM and looking at the server properties in DNS Manager.

![image](images/11.PNG)

This means that any DNS requests are being forwarded to our DNS Server and then on to public Root Hints server off on the public Internet. (You can see these server details within the Root Hunts tab FYI). Unfortunately whilst this is great for enabling a Microsoft DNS Server to function with its default config, it also means that requests are not being sent to Azure DNS (via the special 168 address mentioned earlier), and therefore our use of Azure DNS Private Zones is failing.

We could fix this in one of two ways. Either by enabling a specific forwarder (known as conditional forwarding in DNS) to our database.windows.net zone, or we can just tell our server to forward all requests to Azure DNS by default. We will dig in to the former as part of a later challenge, so lets go with the easier option of updating our global forwarder within DNS Manager to point at Azure DNS.

![image](images/12.PNG)

# Task 4: Verify

Verify:

- Clear the DNS cache on your Azure client VM via 'ipconfig /flushdns'. 
- Clear the DNS cache on your Azure DNS server. (Connect via RDP, browse DNS Manager, right-click server name 'clear cache')
- Re-run nslookup on the client VM in Azure to ensure the Private IP is once again being returned, and you are able to browse via SSMS, proving that Private Link is operational

## :checkered_flag: Results

- You are now using Azure Private Link to access your SQL server alongside the use of a custom DNS server inside of Azure. DNS requests from your client VM within the Spoke VNet are being sent via the Microsoft Windows Server inside of your Hub VNet. This server is configured to send all unknown requests to Azure DNS.














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




# Finished? Delete your lab

- Go to the new folder Private-Endpoint-Hack and run the following command

`terraform destroy`












# Appendix

### Generating SSH keypair

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Generate SSH keypair using the command `ssh-keygen` as shown in the screenshot below

  ![keygen](images/keygen.jpg)

- Use the public key (id_rsa.pub) for the deployment. 
- Download the private key to your desktop using the download button at the top. You will be using this file for logging into the linux VMs 


