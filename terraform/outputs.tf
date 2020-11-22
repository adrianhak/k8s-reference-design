
output "public" {
  value = data.aws_subnet_ids.public.ids
}

/* output "private" {
  value = data.aws_subnet_ids.private.ids
} */

output "ssh-here" {
  value = aws_instance.kubernetes_masters.*.public_ip
}
