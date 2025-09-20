resource "aws_acm_certificate" "main" {
  domain_name       = "*.innovatemart.project.com"
  validation_method = "DNS"
}

# Use data source to get the Route53 zone
data "aws_route53_zone" "selected" {
  name         = aws_route53_zone.main.name
  private_zone = false
  depends_on   = [aws_route53_zone.main]
}

# Create a DNS record for ACM validation
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

# Create an ALIAS record in Route53 pointing to the ALB
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "innovatemart.project.com"
  type    = "A"

  alias {
  # name                   = kubernetes_ingress_v1.retail_store_ingress.status.0.load_balancer.0.ingress.0.hostname
    name		   = "your-alb-dns-name"
    zone_id                = "Z035...." # The canonical hosted zone ID of the ALB, often available via data source
    evaluate_target_health = true
  }
}
