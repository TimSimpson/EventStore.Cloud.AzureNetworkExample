# Azure Networking Example

This example shows how to spin up an Event Store Cloud Network and an Azure Network and then peer the two.

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

To find your Azure tenant, run `az account list` and select the `tenantId` of the appropriate entry.

Run `esc access token display` to get your EventStore Cloud token (use `esc access token create` to make one).

Set the following environment variables:

```bash
export ESC_ORG_ID="<your org ID>"
export TF_VAR_project_id="<your project ID>"
export ESC_TOKEN=$(esc access token display)
export TF_VAR_azure_subscription_id="<tenant ID>"
```

Run the following:

```bash
cd terraform
terraform init
terraform plan
terraform apply  # actually creates resources
terraform destroy  # destroys everything created in the last step
```
