# Kubernetes Reference Design

This is a reference design for a Kubernetes cluster intended to work on-prem with the EFK stack for logging, Prometheus for monitoring and Flux for CD. To test and demo all these features, [Podinfo](https://github.com/stefanprodan/podinfo) is deployed as an example application. 

Provisioning of infrastructure and deployment of the cluster is done through Terraform and Ansible. 


Even though on-prem is the target platform, Terraform is currently configured to use AWS as its provider mainly because of the simplicity of setting up infrastructure on AWS.

# Setup
Begin by forking this repository, make sure you have all the prerequisities installed and set up and then follow the steps below.

## Prerequisities
* [Terraform CLI](https://www.terraform.io/downloads.html) (0.14.3)
* [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (2.9.16)
* [AWS CLI](https://aws.amazon.com/cli/) (1.15.58)
* A VPC containing a public subnet with the tag `Tier: Public`
* An S3 bucket (for remote storage of terraform state)

## AWS Credentials

### AWS Access Keys
Terraform uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for authentication. Create a new access key in the AWS Security Credentials dashboard and download the file containing the access key and the secret key. 
Now run `aws configure` and enter the keys when prompted. 

### EC2 Key Pair
To let Ansible SSH into the EC2 instances you need to generate another key pair. This can be done from the EC2 dashboard. You can name the key whatever you want but by default Terraform expects the name `main-key`. Download the private .pem key and then run `chmod 400 main-key.pem` to set the right permissions . 

## Configuring Terraform

### State backend
Edit `terraform/backend.tf` and enter the name and region of your S3 bucket as well as the name of the key created above. 
```
terraform {
    backend "s3" {
        bucket = "your-bucket-name"
        key    = "your-key-name"
        region = "your-region-name"
    }
}
```

### Variables
The `terraform/variables.tf` file contains the following variables:
| Variable        | Description           | Default value  |
| ------------- |:-------------:| -----:|
| `vpc_id`      | Working VPC ID | (none) |
| `master_node_count`      | Number of master  nodes to create      |   1 |
| `worker_node_count` | Number of worker nodes to create      |    1 |
| `ssh_key_private` | Private key for Ansible to use      | (none) |
| `ssh_access_cidr_block` | IPs allowed to access master nodes via SSH      |    (none) |
| `instance_type` | The EC2 instance type to deploy      |    t3.small |
| `region` | The AWS region to deploy EC2 instances in      |    eu-north-1 |
| `aws_instane_key_name` | The name of the SSH key used      |    main-key |

Keep in mind that `ssh_access_cidr_block` needs to be in CIDR notation. To allow SSH access from your IP address only you would enter your IP address followed by /32.

Variables can be set by either changing the default value or by providing values with the `-var` flag when deploying the cluster. 

## Configuring Flux
Flux is used for deploying resources in the cluster fetched from the `releases/` and `namespaces/` directories in the git repository.  
To allow Flux access to the repository you need to generate a deploy key. 

 Run `ssh-keygen`, name the new key `flux-git-deploy`and save it in `ansible/roles/configure-flux/files/`.  
 
 Copy the contents of `flux-git-deploy.pub` and  add it as a deploy key in the repository (Settings -> Deploy keys -> Add deploy key).  
 The title should be `flux-git-deploy`, also make sure to **allow write access**.

Now edit the `ansible/roles/configure-flux/vars/main.yaml` file and change the variables to match your fork of the repository. 

## Deploying the cluster
With Terraform and Flux configured and all credentials in place it's now possible to deploy it all through Terraform.

First enter the `terraform/` directory and run `terraform init`.

Finally, provision the infrastructure.
### Example
```
terraform apply -var vpc_id=YOUR_VPC_ID \
-var ssh_key_private=main-key.pem \
-var aws_instance_key_name=main-key \
-var ssh_access_cidr_block=YOUR_IP_ADDRESS/32 \
-var master_node_count=2 \
-var worker_node_count=3 


```
# Accessing the cluster
SSH into one of the master nodes using the key created earlier. `ssh -i main-key.pem ubuntu@MASTER_NODE_IP` 

Wait for everything to be deployed in all the different namespaces (default, logging, monitoring, flux).

Grafana, Prometheus, Podinfo and Kibana services are set to be of the type NodePort and can thus be reached externally on their respective ports.

For example, run `kubectl get svc -n monitoring` to see which ports were assigned to the Grafana and Prometheus services. 
```
NAME                                                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                                       ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   3m29s
monitoring-kube-prometheus-alertmanager                     ClusterIP   10.110.153.109   <none>        9093/TCP                     3m41s
monitoring-kube-prometheus-operator                         ClusterIP   10.110.15.253    <none>        443/TCP                      3m41s
monitoring-kube-prometheus-prometheus                       NodePort    10.105.207.36    <none>        9090:30090/TCP               3m41s
monitoring-kube-prometheus-stack-grafana                    NodePort    10.99.117.41     <none>        80:32461/TCP                 3m41s
monitoring-kube-prometheus-stack-kube-state-metrics         ClusterIP   10.99.39.35      <none>        8080/TCP                     3m41s
monitoring-kube-prometheus-stack-prometheus-node-exporter   ClusterIP   10.103.223.85    <none>        9100/TCP                     3m41s
prometheus-operated                                         ClusterIP   None             <none>        9090/TCP                     3m29s
```
In this case, Prometheus is accessible at NODE_IP:30090 and Grafana at NODE_IP:32461.

**Note: Exposing these services as NodePort on publicly accessible hosts is probably not a good idea in a production enviornment.**



