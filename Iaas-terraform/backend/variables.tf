variable "remote-s3-backend-bucket" {
    description = "Name of the S3 bucket to be created"
    type        = string   
    default     = "remote-s3-backend-bucket-terraform"
}

variable "state-lock-table" {
    description = "Name of the DynamoDB table to be created for Terraform state locking"
    type        = string
    default     = "tf-state-lock"
}