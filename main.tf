data "template_file" "user_data" {
  template = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install apache2 -y
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<html><body><h1>Hello, Apache2 is running on your EC2 instance!</h1></body></html>" > /var/www/html/index.html
                EOF
}

resource "aws_launch_template" "example" {
  name           = "${var.name}-${var.namespace}-launch-ec2"
  image_id       = var.ami_id
  instance_type  = var.instance_type
  key_name = var.key_name
 
  user_data = base64encode(data.template_file.user_data.rendered)
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                    = var.subnet_id
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.name}-${var.namespace}"
  }
}

resource "aws_autoscaling_group" "example" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  vpc_zone_identifier  = [var.subnet_id]

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
  health_check_type          = "EC2"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  alarm_actions = [
    aws_autoscaling_policy.scale_up.arn
  ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30

  alarm_actions = [
    aws_autoscaling_policy.scale_down.arn
  ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }
}
