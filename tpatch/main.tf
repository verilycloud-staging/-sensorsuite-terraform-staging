module "tpatch_prod_pipeline" {
  source = "../modules/prod_pipeline"
  pipeline_service_account_name = "streaming-algos"
  project_id = "streaming-tpatch-algos-prod"
  cloud_dataflow_bucket_name = "streaming-tpatch-algos-prod-dataflow"
  sensor_store_pubsub_topic = "projects/sensors-tpatch-fishfood/topics/streaming-algos"
  pubsub_subscription_name = "fishfood-prod-algos"
}
