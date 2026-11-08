output "ec2_instance_id" {
  value = aws_instance.app.id
}
output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}
output "api_url" {
  value = "http://${aws_instance.app.public_ip}:8080/api/health"
}
output "s3_bucket" {
  value = aws_s3_bucket.documents.id
}
output "efs_id" {
  value = aws_efs_file_system.shared.id
}
output "aws_deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
output "region" {
  value = var.region
}
