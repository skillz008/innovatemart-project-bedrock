# terraform/route53.tf
resource "aws_route53_zone" "main" {
  name = "Skillz008.onmicrosoft.com"
  
  tags = {
    Project = var.project_name
    Name    = "${var.project_name}-main-zone"
  }
}
