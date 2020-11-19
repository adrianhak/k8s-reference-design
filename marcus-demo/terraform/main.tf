data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Private"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Public"
  }
}

resource "aws_security_group" "kubernetes_masters_marcus" {
  name        = "kubernetes_masters_marcus"
  description = "kubernetes_masters_marcus"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["178.21.87.8/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes_masters_marcus"
  }
}

resource "aws_security_group" "kubernetes_workers_marcus" {
  name        = "kubernetes_workers_marcus"
  description = "kubernetes_workers_marcus"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["178.21.87.8/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes_workers_marcus"
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
  instance_type          = "t3.medium"
  subnet_id              = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  vpc_security_group_ids = [aws_security_group.kubernetes_masters_marcus.id]
  key_name               = "marcus-kubernetes-key"
  tags = {
    Name = format("kubernetes-master-node-%s", count.index)
  }

  provisioner "remote-exec" {
    inline = ["echo Im in!!!"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key_private)
    }
  }
}

resource "aws_instance" "kubernetes_workers" {
  count                  = var.worker_node_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = element(tolist(data.aws_subnet_ids.public.ids), count.index)
  vpc_security_group_ids = [aws_security_group.kubernetes_workers_marcus.id]
  key_name               = "marcus-kubernetes-key"

  tags = {
    Name = format("kubernetes-worker-node-%s", count.index)
  }

  provisioner "remote-exec" {
    inline = ["echo Im in!!!"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key_private)
    }
  }
}

resource "null_resource" "install-kubernetes-master" {
  depends_on = [aws_instance.kubernetes_masters]
  count      = var.master_node_count
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -T 300 -i ${element(aws_instance.kubernetes_masters.*.public_ip, count.index)}, --user ubuntu --private-key ${var.ssh_key_private} ../ansible/provision-master.yaml"
  }
}

resource "null_resource" "install-kubernetes-worker" {
  depends_on = [aws_instance.kubernetes_workers]
  count      = var.worker_node_count
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -T 300 -i ${element(aws_instance.kubernetes_workers.*.public_ip, count.index)}, --user ubuntu --private-key ${var.ssh_key_private} ../ansible/provision-worker.yaml"
  }
}

