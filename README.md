# Azure Networking Example

This example shows how to spin up an Event Store Cloud Network and an Azure Network and then peer the two.

It also creates a (not very secure) VM you can log into with SSH in order to contact the EventStore cluster.

## Prereqs

* [terraform](https://www.terraform.io/)
* [az (Azure CLI)](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
* [esc (EventStore Cloud CLI)](https://github.com/EventStore/esc)
* [just](https://github.com/casey/just/#readme) (optional)
* [jq](jq) (optional)

Plus of course an EventStore Cloud account and login.

## Running

Run `az login` to log into Azure.

Run `az account show` to make sure you're using the account you think you are.

Run `esc access tokens display` to get your EventStore Cloud token (use `esc access tokens create` to make one).

Set the following environment variables:

```bash
export TF_VAR_stage="${USER}"
export ESC_ORG_ID="<your org ID>"
export TF_VAR_project_id="<your project ID>"
export ESC_TOKEN=$(esc access tokens display)
export TF_VAR_ssh_password="put something good here"
```

Run the following:

```bash
cd terraform
terraform init
terraform plan
terraform apply  # actually creates resources
export VM_IP=$(terraform output | jq -r '.vm_ip_address.value')
ssh 'cloudperson@${VM_IP}'
```

use the password you set to TF_VAR_ssh_password.

At this point you can test access to any cluster you provision to the Azure network by curl'ing the gossip endpoint:

```bash
curl https://ciap03to0aetpuc6e1pg.mesdb.eventstore.cloud:2113/gossip
```