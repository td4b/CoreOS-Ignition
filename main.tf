# Configure state file for our main tf script.
terraform {
  backend "s3" {
    bucket = "labstatebucket"
    key    = "labstatebucket/main.tfstate"
    region = "us-west-1"
  }
}

provider "aws"{
  region = "us-west-1"
}

variable "docker_username" {
  type = "string"
}

variable "docker_password" {
  type = "string"
}

variable "ami" {
  default = "ami-007fd5d3faa277be8" # CoreOS
}

//
// iam role
//

resource "aws_iam_policy" "ssmpolicy" {
  name = "ssmPolicy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
       "Sid": "SSMDescribe",
       "Action": [
          "ssm:DescribeParameters"
        ],
        "Resource": "*",
        "Effect": "Allow"
     },
     {
       "Sid": "SSMPermissions",
       "Action": [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        "Resource": "*",
        "Effect": "Allow"
      },
      {
        "Sid": "SSMDescrypt",
        "Action": [
           "kms:Decrypt"
         ],
         "Resource": "*",
         "Effect": "Allow"
      }
  ]
}
EOF
}

resource "aws_iam_role" "ssmrole" {
  name = "ssmRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm-attachment" {
  role       = "${aws_iam_role.ssmrole.name}"
  policy_arn = "${aws_iam_policy.ssmpolicy.arn}"
}

resource "aws_iam_instance_profile" "ssm-instance-profile" {
  name = "ssm-instance-profile"
  role = "${aws_iam_role.ssmrole.name}"
}

//
// secrets
//

resource "aws_ssm_parameter" "secretkey" {
  name  = "/dev/secretkey"
  type  = "SecureString"
  value = "supersecretkey"
}

//
// confd service container
//

data "template_file" "confd_service" {
  template = "${file("confd.service.tpl")}"
}

data "ignition_systemd_unit" "confd_service" {
  name = "confd.service"
  content = "${data.template_file.confd_service.rendered}"
}

//
// ignition
//

data "template_file" "config_toml" {
  template = "${file("myconfig.toml")}"
}

data "ignition_file" "configtoml" {
    filesystem = "root"
    path = "/etc/confd/conf.d/myconfig.toml"
    content {
        content = "${data.template_file.config_toml.rendered}"
}
}

data "template_file" "config_file" {
  template = "${file("myconfig.conf.tmpl")}"
}

data "ignition_file" "configfile" {
    filesystem = "root"
    path = "/etc/confd/templates/myconfig.conf.tmpl"
    content {
        content = "${data.template_file.config_file.rendered}"
}
}

data "template_file" "login" {
  template = "${file("login.service")}"
  vars {
    docker_username = "${var.docker_username}"
    docker_pw = "${var.docker_password}"
  }
}

data "ignition_systemd_unit" "login" {
  name = "login.service"
  content = "${data.template_file.login.rendered}"
}

data "ignition_config" "ignition" {

  systemd = [
    "${data.ignition_systemd_unit.login.id}",
    "${data.ignition_systemd_unit.confd_service.id}",
  ]

  files = [
      "${data.ignition_file.configtoml.id}",
      "${data.ignition_file.configfile.id}",
  ]
}

//
// network security
//

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id = "vpc-0dd1ac922930e40b2"
  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    # Opens port 80 for the honey pot.
    cidr_blocks = ["24.130.143.12/32"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

}

//
// compute
//

# automatically deploys to default vpc - 172.31.0.0/16
resource "aws_spot_instance_request" "cheap_worker" {
  ami           = "${var.ami}"
  spot_price    = "0.01"
  instance_type = "t2.micro"
  subnet_id     = "subnet-0603b49c9f38a102a"
  key_name = "tewest"
  associate_public_ip_address = true
  iam_instance_profile = "${aws_iam_instance_profile.ssm-instance-profile.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}"]
  user_data = "${data.ignition_config.ignition.rendered}"
  tags = {
    Name = "CheapWorker"
  }
}

output "file_loc" {
  value = "${data.ignition_file.configtoml.id}"
}
