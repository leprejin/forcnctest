resource "aws_vpc" "awsvpc" {
  cidr_block           = "115.0.0.0/16"
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
  cidr_block        = "115.0.1.0/24"
}

resource "aws_eip" "awseip" {
  vpc = false
}

resource "aws_nat_gateway" "natgate_1a" {
  allocation_id = "${aws_eip.awseip.id}"
  subnet_id     = "${aws_subnet.public_1a.id}"
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
  ]
}

variable "amazon_linux" {
  # Amazon Linux AMI 2017.03.1 (HVM), SSD Volume Type - ami-4af5022c
  default = "ami-4af5022c"
}

resource "aws_security_group" "webserverSecurutyGroup" {
  name        = "webserverSecurutyGroup"
  description = "open ssh port for webserverSecurutyGroup"

  vpc_id = "${aws_vpc.awsvpc.id}"
/*
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
*/
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

resource "aws_launch_configuration" "launchconfig" {
    name_prefix = "launchconfig"
    image_id = "${var.amazon_linux}"
    instance_type = "t2.micro"
    key_name = "user15-key"
    security_groups = ["${aws_security_group.webserverSecurutyGroup.id}"]
}
resource "aws_autoscaling_group" "user15_autoscaling" {
    name = "user15_autoscaling"
    vpc_zone_identifier = ["${aws_subnet.public_1a.id},"]
    launch_configuration = "${aws_launch_configuration.launchconfig.name}"
    min_size = 3
    max_size = 3
    health_check_grace_period = 300
    health_check_type = "EC2"
    force_delete = true
    tag {
        key = "Name"
        value = "ec2 instance"
        propagate_at_launch = true
    }
}

# scale up alarm
resource "aws_autoscaling_policy" "cpu-policy" {
    name = "cpu-policy"
    autoscaling_group_name = "${aws_autoscaling_group.user15_autoscaling.name}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = "1"
    cooldown = "300"
    policy_type = "SimpleScaling"
}
resource "aws_cloudwatch_metric_alarm" "cpu-alarm" {
    alarm_name = "cpu-alarm"
    alarm_description = "cpu-alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "30"
    dimensions = {
        "AutoScalingGroupName" = "${aws_autoscaling_group.user15_autoscaling.name}"
    }
    actions_enabled = true
    alarm_actions = ["${aws_autoscaling_policy.cpu-policy.arn}"]
}
# scale down alarm
resource "aws_autoscaling_policy" "cpu-policy-scaledown" {
    name = "cpu-policy-scaledown"
    autoscaling_group_name = "${aws_autoscaling_group.user15_autoscaling.name}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = "-1"
    cooldown = "300"
    policy_type = "SimpleScaling"
}
resource "aws_cloudwatch_metric_alarm" "cpu-alarm-scaledown" {
    alarm_name = "cpu-alarm-scaledown"
    alarm_description = "cpu-alarm-scaledown"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "120"
    statistic = "Average"
    threshold = "5"
    dimensions = {
        "AutoScalingGroupName" = "${aws_autoscaling_group.user15_autoscaling.name}"
    }
    actions_enabled = true
    alarm_actions = ["${aws_autoscaling_policy.cpu-policy-scaledown.arn}"]
}
