# shakesapp demo runner

Scaffolding project to run shakesapp demo on Google Compute Engine.

## Requirements

* terraform
* ansible

## How to run

1. Prepare service account, download credential file and place it to the right place.
2. Modify `deploy.tf` and `deploy.yaml` to fit your case
3. Run the following command.

```
terraform apply -auto-approve
```
