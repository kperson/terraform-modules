module "dynamo_hash" {
  source           = "../auto-scaled-dynamo"
  table_name       = "my_auto_scaled_table"
  hash_key         = "myId"
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attributes = [
    {
      name = "myId"
      type = "S"
    }
  ]
}
