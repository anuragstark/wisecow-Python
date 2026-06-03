terraform {
  backend "s3" {
    bucket         = "wisecow-backend-7165"
    key            = "wisecow/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wisecow"
    encrypt        = true
  }
}
