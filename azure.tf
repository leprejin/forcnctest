resource "aws_vpc" "awsvpc" {
  cidr_block           = "101.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}

resource "aws_internet_gateway" "awsipg" {
  vpc_id = "${aws_vpc.awsvpc.id}"
}

resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.awsvpc.id}"
  availability_zone = "ap-northeast-1a"
  cidr_block        = "101.0.1.0/24"
}

resource "aws_subnet" "public_1d" {
  vpc_id            = "${aws_vpc.awsvpc.id}"
  availability_zone = "ap-northeast-1d"
  cidr_block        = "101.0.2.0/24"
}

resource "aws_eip" "awseip3" {
  vpc = false
}

resource "aws_eip" "awseip4" {
  vpc = false
}
/*
resource "aws_eip" "awspubeip" {
  vpc = false  
}
*/
resource "aws_nat_gateway" "natgate_1a" {
  allocation_id = "${aws_eip.awseip3.id}"
  subnet_id     = "${aws_subnet.public_1a.id}"
}

resource "aws_nat_gateway" "natgate_1d" {
  allocation_id = "${aws_eip.awseip4.id}"
  subnet_id     = "${aws_subnet.public_1d.id}"
}

resource "aws_route_table" "awsrtp" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.awsipg.id}"
  }
}

resource "aws_route_table_association" "awsrtp1a" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
}

resource "aws_route_table_association" "awsrtp1d" {
  subnet_id      = "${aws_subnet.public_1d.id}"
  route_table_id = "${aws_route_table.awsrtp.id}"
}

resource "aws_default_security_group" "awssecurity" {
  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 

resource "aws_default_network_acl" "awsnetworkacl" {
  default_network_acl_id = "${aws_vpc.awsvpc.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1d.id}",
  ]
}

variable "amazon_linux" {
  # Amazon Linux AMI 2017.03.1 (HVM), SSD Volume Type - ami-4af5022c
  default = "ami-4af5022c"
}
/*
variable "dev_keyname" {
  default = "david-key"
}
*/

resource "aws_security_group" "webserverSecurutyGroup" {
  name        = "webserverSecurutyGroup"
  description = "open ssh port for webserverSecurutyGroup"

  vpc_id = "${aws_vpc.awsvpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web3" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-1a"
  instance_type     = "t2.micro"
  key_name = "key"
  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]

  subnet_id                   = "${aws_subnet.public_1a.id}"
  associate_public_ip_address = true
}

resource "aws_instance" "web4" {
  ami               = "${var.amazon_linux}"
  availability_zone = "ap-northeast-1d"
  instance_type     = "t2.micro"
  key_name = "key"

  vpc_security_group_ids = [
    "${aws_security_group.webserverSecurutyGroup.id}",
    "${aws_default_security_group.awssecurity.id}",
  ]

  subnet_id                   = "${aws_subnet.public_1d.id}"
  associate_public_ip_address = true
}

resource "aws_lb" "lb" {
  name               = "lb"
  load_balancer_type = "network"
  ip_address_type = "ipv4"

  subnet_mapping {
    subnet_id     = "${aws_subnet.public_1a.id}"
    allocation_id = "${aws_eip.awseip3.id}"
  }

  subnet_mapping {
    subnet_id     = "${aws_subnet.public_1d.id}"
    allocation_id = "${aws_eip.awseip4.id}"
  }
}

/*
resource "aws_alb" "frontend" {
  name            = "alb"
  internal        = false
  security_groups = ["${aws_security_group.webserverSecurutyGroup.id}"]
  subnets         = [
    "${aws_subnet.public_1a.id}",
    "${aws_subnet.public_1d.id}"
  ]

  access_logs {
    bucket  = "${aws_s3_bucket.alb.id}"
    prefix  = "frontend-alb"
    enabled = true
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_s3_bucket" "alb" {
  bucket = "alb-log-example.com"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::582318560864:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::alb-log-example.com/*"
    }
  ]
}
  EOF

  lifecycle_rule {
    id      = "log_lifecycle"
    prefix  = ""
    enabled = true

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_alb_target_group" "frontend" {
  name     = "frontend-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.awsvpc.id}"

  health_check {
    interval            = 30
    path                = "/ping"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

*/
/*
resource "aws_alb_target_group" "frontend2" {
  name     = "static-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.awsvpc.id}"

  health_check {
    interval            = 30
    path                = "/ping"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}


resource "aws_alb_target_group_attachment" "frontend1" {
  target_group_arn = "${aws_alb_target_group.frontend.arn}"
  target_id        = "${aws_instance.web3.id}"
  port             = 8080
}

resource "aws_alb_target_group_attachment" "frontend2" {
  target_group_arn = "${aws_alb_target_group.frontend.arn}"
  target_id        = "${aws_instance.web4.id}"
  port             = 8080
}


data "aws_acm_certificate" "example_dot_com"   {
  domain   = "*.example.com."
  statuses = ["ISSUED"]
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.example_dot_com.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontend.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontend.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "static" {
  listener_arn = "${aws_alb_listener.https.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.static.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/static/*"]
  }
}


resource "aws_route53_zone" "example" {
  name = "example43838341923.com."
}

resource "aws_route53_record" "frontend_A" {
  zone_id = "${aws_route53_zone.example.zone_id}"
  name    = "example43838341923.com"
  type    = "A"

  alias {
    name     = "${aws_alb.frontend.dns_name}"
    zone_id  = "${aws_alb.frontend.zone_id}"
    evaluate_target_health = true
  }
}
*/
