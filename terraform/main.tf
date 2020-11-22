data "aws_vpc" "selected" {
  id = var.vpc_id
}

/* data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Private"
  }
} */

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Public"
  }
}

resource "aws_security_group" "kubernetes_masters" {
  name        = "kubernetes_masters"
  description = "kubernetes_masters"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr_block]
  }

    # Allow only internal incoming traffic
    ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes_masters"
  }
}

resource "aws_security_group" "kubernetes_workers" {
  name        = "kubernetes_workers"
  description = "kubernetes_workers"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes_workers"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "kubernetes_masters" {
  count                  = var.master_node_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  vpc_security_group_ids = [aws_security_group.kubernetes_masters.id]
  key_name               = var.aws_instance_key_name
  associate_public_ip_address = "true"
  tags = {
    Name = format("kubernetes-master-node-%s", count.index)
  }


}

resource "aws_instance" "kubernetes_workers" {
  count                  = var.worker_node_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  vpc_security_group_ids = [aws_security_group.kubernetes_workers.id]
  key_name               = var.aws_instance_key_name
  associate_public_ip_address = "true"

  tags = {
    Name = format("kubernetes-worker-node-%s", count.index)
  }


}

resource "null_resource" "check-master-connections" {
    depends_on = [aws_instance.kubernetes_masters]
    count      = var.master_node_count
    provisioner "remote-exec" {
    inline = ["echo Im in!!!"]

    connection {
      host        = element(aws_instance.kubernetes_masters.*.public_ip, count.index)
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key_private)
    }
  }
}

resource "null_resource" "check-worker-connections" {
  depends_on = [aws_instance.kubernetes_workers]
  count      = var.worker_node_count
    provisioner "remote-exec" {
    inline = ["echo Im in!!!"]

    connection {
      host        = element(aws_instance.kubernetes_workers.*.public_ip, count.index)
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key_private)
    }
  }
}

resource "null_resource" "install-kubernetes-master" {
  depends_on = [null_resource.check-master-connections]
  count      = var.master_node_count
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -T 300 -i ${element(aws_instance.kubernetes_masters.*.public_ip, count.index)}, --user ubuntu --private-key ${var.ssh_key_private} ../ansible/provision-master.yaml -e ansible_python_interpreter=/usr/bin/python3"
  }
}

resource "null_resource" "install-kubernetes-worker" {
  depends_on = [null_resource.check-worker-connections]
  count      = var.worker_node_count
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -T 300 -i ${element(aws_instance.kubernetes_workers.*.public_ip, count.index)}, --extra-vars master_ip=${aws_instance.kubernetes_masters.0.private_ip} --user ubuntu --private-key ${var.ssh_key_private} ../ansible/provision-worker.yaml -e ansible_python_interpreter=/usr/bin/python3"
  }
}

