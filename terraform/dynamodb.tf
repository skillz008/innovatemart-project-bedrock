# main-dynamodb.tf
resource "aws_dynamodb_table" "carts" {
  name         = "${var.project_name}-Carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}
