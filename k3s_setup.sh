#!/bin/bash

# Install k3s on the server node
ssh -i /key.pem ec2-user@${k3s_server_ip} "curl -sfL https://get.k3s.io | sh -"

# Get the node token from the server
NODE_TOKEN=$(ssh -i /key.pem ec2-user@${k3s_server_ip} "sudo cat /var/lib/rancher/k3s/server/node-token")

# Install k3s on the agent node
ssh -i /key.pem ec2-user@${k3s_agent_ip} "curl -sfL https://get.k3s.io | K3S_URL=https://${k3s_server_ip}:6443 K3S_TOKEN=$NODE_TOKEN sh -"

# Verify the cluster
ssh -i /key.pem ec2-user@${k3s_server_ip} "sudo kubectl get nodes"