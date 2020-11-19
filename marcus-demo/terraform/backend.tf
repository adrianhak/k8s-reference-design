terraform {
  backend "s3" {
    bucket = "marcus-terraform-state-bucket"
    key    = "demo"
    region = "eu-west-1"
  }
}
