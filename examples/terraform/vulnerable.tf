provider "aws" {
  region = "us-east-1"
}

# INTENTIONAL VULNERABILITY: Public S3 Bucket
resource "aws_s3_bucket" "public_bucket" {
  bucket = "fortressci-public-demo-bucket"
  acl    = "public-read"
}

# INTENTIONAL VULNERABILITY: Unencrypted S3 Bucket
resource "aws_s3_bucket" "unencrypted_bucket" {
  bucket = "fortressci-unencrypted-demo-bucket"
}

# INTENTIONAL VULNERABILITY: Open Security Group
resource "aws_security_group" "open_sg" {
  name        = "open-sg"
  description = "Allow all inbound traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
