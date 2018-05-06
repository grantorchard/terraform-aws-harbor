# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A HARBOR CLUSTER WITH ELB IN AWS
# This is an example of how to use the vault-cluster and vault-elb modules to deploy a Vault cluster in AWS with an 
# Elastic Load Balancer (ELB) in front of it. This cluster uses Consul, running in a separate cluster, as its storage 
# backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "harbor" {
  most_recent = true

  # If we change the AWS Account in which test are run, update this value.
  owners = ["495078824317"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "is-public"
    values = ["false"]
  }

  filter {
    name   = "name"
    values = ["ubuntu-16.04-*"]
    #values = ["harbor-ubuntu-*"]
  }
}

resource "aws_security_group" "harbor" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "vpc-eca7ad8e"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "harbor" {
  ami           = "${data.aws_ami.harbor.id}"
  instance_type = "t2.micro"
  key_name      = "grant_pub"
  #security_groups = ["${aws_security_group.harbor.id}"]
  tags {
    Name = "test"
  }
  provisioner "file" {
    source = "modules/install-harbor/install-harbor"
    destination = "/tmp"
  }
      /*
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/reg\\.mydomain\\.com/harbor\\.grantorchard\\.com/' /opt/harbor/harbor.cfg",
      "sudo sed -i 's/ui_url_protocol = http/ui_url_protocol = https/' /opt/harbor/harbor.cfg"
    ]
    connection {
    type     = "ssh"
    private_key = "${file("~/sslcerts/grant_priv.key")}"
    }
  }

  ssl_cert = /data/cert/server.crt
  ssl_cert_key = /data/cert/server.key
  */
}

data "aws_route53_zone" "wwko2018" {
  name         = "wwko2018.com."
  private_zone = false
}

resource "aws_route53_record" "harbor" {
  zone_id = "${data.aws_route53_zone.wwko2018.zone_id}"
  name    = "${aws_instance.harbor.tags.Name}.${data.aws_route53_zone.wwko2018.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.harbor.public_ip}"]
}
