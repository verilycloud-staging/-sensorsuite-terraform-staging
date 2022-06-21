# sensorsuite-terraform
Terraform modules used by SensorSuite.

## Update Kumo Submodule

```
git submodule update --remote kumo
```

Then create a PR with the update.

## Testing locally

You will need to check out this repo and the kumo terraform repo to test the
terraform locally.

The repos should have a directory structure like this:

```
./
├── sensorsuite-terraform/
├── kumo-terraform-modules/
```

This ensures that the directory structure is the same as when Plato executes it
as a custom resource.

To checkout this repo run:

```
git clone git@github.com:verily-src/sensorsuite-terraform.git
```

To checkout the kumo repo run:

```
git clone git@github.com:verily-src/kumo-terraform-modules.git
```

Then you can navigate to the modules you would like to test.

```
cd modules/study_setup
```

And run:

```
terraform init
terraform plan
```

To test the output of the terraform script.
