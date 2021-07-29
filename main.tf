provider "aws" {
  region  = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "<replace-with-s3-bucket>"
    key    = "eu-west-1/tfstate.json"
    region = "eu-west-1"
    dynamodb_table = "<replace-with-dynamodb-table>"
    encrypt = true
  }
}

resource "random_id" "id" {
  byte_length = 2
}
