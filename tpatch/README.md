Terraform script for managing the tPatch prod pipeline project (streaming-tpatch-algos-prod)

NOTE: To finialize this you will need to manually update the secret `ds-sdk-api-key` to contain an API key. And grant the created service account the `Dataflow Worker` role and `Service Account `on the project.

Terraform changes can be run with:

```
terraform apply
```

The API key for calling SensorStore is a required variable. The existing API key can be found here: https://pantheon.corp.google.com/apis/credentials?project=streaming-tpatch-algos-prod