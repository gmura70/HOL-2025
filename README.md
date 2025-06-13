# HOL-2025 (Hands on Lab 2025)

## 1 - Set up the TechZone vm
When provisionin the VM, choose a 8-core, 32GB memory configuration in order to have enough resources to run all the components required

Use this base image: https://techzone.ibm.com/my/reservations/ibmcloud-2/680a68790b3f018ca424cac7

Once the VM is up and running follow these steps:

1. download the SSH key to your laptop and store it in ~/.ssh/ directory (by default its name is pem_ibmcloudvsi_download.pem)
2. edit your ~/.ssh/config file and add the following lines:
```
# simple connection to TechZone VM
Host rhel
HostName <Public IP address of VM>
Port 2223
User itzuser
IdentityFile ~/.ssh/pem_ibmcloudvsi_download.pem

# Connection to the TechZone VM but with port forwarding to localhost so services can be reached from the browser
Host rhel2
HostName <Public IP address of VM>
Port 2223
User itzuser
IdentityFile ~/.ssh/pem_ibmcloudvsi_download.pem
LocalForward 8080 localhost:8080
LocalForward 5601 localhost:5601
LocalForward 9200 localhost:9200
LocalForward 18630 localhost:18630
```
## 2 - Clone this repo

Download this repo to your laptop's hard drive or clone the repo via the git command line 

```
git clone https://github.com/gmura70/HOL-2025
```
Note: this assumes you have git command line installed; if you haven't proceed to install it as per your OS's standard install of git cli.

Also note: this repo contain the file **externalResources.zip** - this is referenced by the StreamSets Data Collector in the org used by the Lab and it contains required libraries (e.g. the SingleStore JDBC library):

<img width="1281" alt="image" src="https://github.com/user-attachments/assets/f802a2c8-e4ba-417a-8be6-c850f7d887a0" />

## 3 - Edit the .env file to configure the environment variables

Edit the *.env* file; the following variables need to be filled in with details of your TechZone host, which you have got in step 1.

```
SSH_KEY_PATH=~/.ssh/pem_ibmcloudvsi_download.pem
REMOTE_HOST=158.177.14.230
SSH_PORT=2223
REMOTE_USER=itzuser
```

Get the values for these variables from your StreamSets Deployment in Control Hub

```
DEPLOYMENT_ID=<your deployment id goes here>
DEPLOYMENT_TOKEN=<your deployment token goes here>
STREAMSETS_IMAGE=docker.io/streamsets/datacollector:JDK17_6.2.0
STREAMSETS_SCH_URL=https://eu01.hub.streamsets.com
```
**Note!** The STREAMSETS_IMAGE settings here use **docker.io** image repo, as for some reason podman doesn't find the image otherwise!

## 4 - Run the setupLocal.sh file

The setup file performs installation of all the required software components on the the TechZone VM. It copies docker-compose.yml file to the TZ VM and it executes the setupOnTZ.sh script on it after copying it there.

Make the script executable and run it:
```
chmod +x setup.sh
./setupLocal.sh
```

once that's completed successfully you can open a ssh session with port forwarding to the VM and then test that e.g. Singlestore or Elastic are running properly:

```
ssh rhel2
```

then using your browser open a connection to:

Singlestore: http://localhost:8080
Kibana: http://localhost:5601/app/home#/

## 5 - Troubleshooting

On the TZ machine you'll find a log file in the itzuser home directory (setupOnTZ.log) which will give you an indication of what's been executed and of anything that might have gone wrong.


Should you need to clean up the VM, assuming you've set up your .ssh/config file as described in section 1, do the following:

```
ssh rhel
podman-compose down
```


