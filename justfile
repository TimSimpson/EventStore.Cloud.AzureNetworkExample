set shell := ["bash", "-uc"]

_default:
    @just --list

# List Azure accounts
show_azure_accounts:
    az account list

# Show the first tenant ID (may not be the one you want!)
first_azure_tenant_id:
    az account list |jq -r '.[0].tenantId'

# show EventStore Cloud Token
esc_token:
    esc access tokens display

# show plan
plan:
    #!/usr/bin/env bash
    pushd terraform
    terraform init
    terraform plan
    popd

# deploys changes
deploy:
    #!/usr/bin/env bash
    pushd terraform
    terraform init
    terraform apply
    popd

destroy:
    #!/usr/bin/env bash
    pushd terraform
    terraform init
    terraform destroy
    popd
