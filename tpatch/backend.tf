terraform {
  backend "gcs" {
    bucket = "sensorsuite-tf-state"
    prefix = "tpatch_pipeline_project"
  }
}
