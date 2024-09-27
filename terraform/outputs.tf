output "k3s_server_public_ip" {
  value = aws_instance.k3s_server.public_ip
}

output "k3s_agent_public_ip" {
  value = aws_instance.k3s_agent.public_ip
}

output "k3s_server_private_ip" {
  value = aws_instance.k3s_server.private_ip
}