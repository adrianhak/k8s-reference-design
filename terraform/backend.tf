terraform {
    backend "s3" {
        bucket = "adrian-terraform-state-bucket"
        key    = "main-key"
        region = "eu-north-1"
    }
}