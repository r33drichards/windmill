terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "windmill" {
  name = "windmill"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/windmill"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "windmill" {
  name        = "windmill"
  description = "Allow access to secrets"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
     {
        Effect = "Allow",
        Action = [
          "s3:*"
        ],
        Resource = "${aws_s3_bucket.windmill.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "windmill" {
  role       = aws_iam_role.windmill.name
  policy_arn = aws_iam_policy.windmill.arn
}

resource "random_id" "windmill" {
  byte_length = 8
}

resource "aws_s3_bucket" "windmill" {
  bucket = "windmill-${random_id.windmill.hex}"

  tags = {
    Name = "windmill"
  }
}

resource "aws_s3_bucket_policy" "windmill" {
  bucket = aws_s3_bucket.windmill.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.windmill.arn
        },
        Action = [
          "s3:*",
        ],
        Resource = [
            "${aws_s3_bucket.windmill.arn}/*",
            "${aws_s3_bucket.windmill.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "windmill" {
  name = "windmill"
}

resource "aws_iam_user_policy" "windmill" {
  name = "windmill"
  user = aws_iam_user.windmill.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Resource = aws_iam_role.windmill.arn
      }
    ]
  })
}

resource "aws_iam_access_key" "windmill" {
  user = aws_iam_user.windmill.name
}

output "access_key" {
  value = aws_iam_access_key.windmill.id
}

output "secret_key" {
  value     = aws_iam_access_key.windmill.secret
  sensitive = true
}

output "role_arn" {
  value = aws_iam_role.windmill.arn
}

output "bucket_url" {
  value = aws_s3_bucket.windmill.bucket
}

data "aws_caller_identity" "current" {}
