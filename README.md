# HOL-2025 (Hands on Lab 2025)

## 1 - setup the TechZone vm
When provisionin the VM, choose a 8-core, 32GB memory configuration in order to have enough resources to run all the components required

Use this base image: https://techzone.ibm.com/my/reservations/ibmcloud-2/680a68790b3f018ca424cac7

Once the VM is up and running follow these steps:

1. download the SSH key to your laptop and store it in ~/.ssh/ directory (by default its name is pem_ibmcloudvsi_download.pem)
2. edit your ~/.ssh/config file and add the following lines:
```
Host rhel
HostName <Public IP address of VM>
Port 2223
User itzuser
IdentityFile ~/.ssh/pem_ibmcloudvsi_download.pem
LocalForward 8080 localhost:8080
LocalForward 5601 localhost:5601
LocalForward 9200 localhost:9200
LocalForward 18630 localhost:18630
```
3. ssh to the VM

`ssh rhel`

on your laptop 

## 2 - clone this repo

1.Install the git utilities

`sudo yum install -y git`

2.Clone the repo

`git clone https://github.com/gmura70/HOL-2025/blob/main/externalResources.zip`

## 3 - Edit the .env file to configure the environment variables

Edit the *.env* file,specifically focus on the following variables; get the values for these variables from your StreamSets Deployment in Control Hub
```
export DEPLOYMENT_ID=<your deployment id goes here>
export DEPLOYMENT_TOKEN=<your deployment token goes here>
export STREAMSETS_IMAGE=streamsets/datacollector:JDK17_6.2.0
export STREAMSETS_SCH_URL=https://eu01.hub.streamsets.com
```

## 4 - Run the setup.sh file

The setup file performs installs all the required software components on the VM, performing the following actions
1. installs podman and podman-compose
2. creates a /data directory - this is used by the Data Collector container - SDC can then use this directory to read/write files accessible by the VM itself.
3. executes docker compose command to run all the container required for the demo

make the script executable and run it:
```
chmod +x setup.sh
./setup.sh
```

## 5 - Create tables in SingleStore

The run_sql_script.sh creates the required tables in singlestore database.

make the script executable and run it:
```
chmod +x run_sql_script.sh
./run_sql_script.sh
```


