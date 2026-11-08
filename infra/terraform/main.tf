data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name   = var.project_name
  bucket = "${var.project_name}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "documents" {
  bucket        = local.bucket
  force_destroy = false
  tags          = { Project = local.name }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_security_group" "ec2" {
  name_prefix = "${local.name}-ec2-"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description = "API docente desde IP autorizada"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_api_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${local.name}-efs-"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "shared" {
  creation_token  = local.name
  encrypted       = true
  throughput_mode = "elastic"
  tags            = { Name = "${local.name}-efs" }
}

# Una sola interfaz EFS por AZ, aunque existan multiples subredes de la misma AZ.
resource "aws_efs_mount_target" "shared" {
  for_each       = { for s in values(data.aws_subnet.selected) : s.availability_zone => s.id... }
  file_system_id = aws_efs_file_system.shared.id
  subnet_id      = each.value[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_iam_role" "ec2" {
  name = "${local.name}-instance-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bucket" {
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${aws_s3_bucket.documents.arn}/clientes/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-${random_id.suffix.hex}"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = values(data.aws_subnet.selected)[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    efs_id = aws_efs_file_system.shared.id
    region = var.region
  })
  user_data_replace_on_change = true
  depends_on                  = [aws_efs_mount_target.shared]
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  tags = { Name = "${local.name}-app", Project = local.name }
}

# CUIDADO: solo puede existir un proveedor OIDC GitHub por cuenta AWS.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "deploy" {
  name = "${local.name}-deploy-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.github_environment}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:SendCommand"]
        Resource = ["arn:aws:ssm:${var.region}::document/AWS-RunShellScript", aws_instance.app.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation"]
        Resource = "*"
      }
    ]
  })
}
