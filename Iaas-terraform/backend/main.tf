provider "aws" {
    region = "ap-south-1"
}

resource "aws_s3_bucket" "s3-backend-bucket" {
  bucket = var.remote-s3-backend-bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "My bucket"
  }
}

resource "aws_dynamodb_table" "tf-state-lock" {
  name           = var.state-lock-table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "state-lock-table"
  }
}