# Terraform-Deploying-Simple-AWS-Architecture  

The objective of this project is to create a simple infrastructure on AWS. The requirements are specified below.

------------------

### Architecture

1. AWS us-east-2.
2. VPC: 10.0.0.0/16.
3. Public subnet: 10.0.0.0/24 and 10.0.1.0/24
4. Security group: Nginx
5. Instance 1: t2.micro
6. Instance 2: t2.micro
7. Ami: amzn2-ami-hvm-x86_64-gp2
8. Load Balancer

![Architecture](/images/architecture.PNG)

------------------

### Description

1. **Providers**: Refers to the cloud that will be used (AWS, GCP, AZURE...). 
  - We will use AWS for this project.
    - The `access_key`, `secret_key` and `region` fields must be filled in according to your AWS account data.

```
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
```   

OBS: As good practice, now we're storying the data in environment variables:

~~~
# # Instead of storing our AWS keys in input variables, we will instead store them in environment variables. The AWS provider will check for values stored in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.

# For Linux and MacOS
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY

# For PowerShell
$env:AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
~~~


2. **Data**: We use the word `data` to specify that this is a data source. 
  - The `aws_ssm_parameter` resource creates an SSM parameter in AWS Systems Manager Parameter Store. 
    - The `name` is (Required) argument and is name of the parameter.

```
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
```

3. **Resources**: We specify the resources used in the infrastructure.
  - The `aws_vpc` provides details about a specific VPC. This resource can prove useful when a module accepts a vpc id as an input variable and needs to, for example, determine the CIDR block of that VPC. 
      - `cidr_block` - (Optional) The cidr block of the desired VPC. 
      - `enable_dns_hostnames` - Whether or not the VPC has DNS hostname support

~~~
# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}
~~~

  - The `aws_internet_gateway` Provides a resource to create a VPC Internet Gateway.
    - `vpc_id` (Optional) The VPC ID to create in


~~~
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}
~~~

  - Provides an VPC subnet resource
    - `cidr_block` (Optional) The IPv4 CIDR block for the subnet.
    - `vpc_id` (Required) The VPC ID.
    - `map_public_ip_on_launch` (Optional) Specify true to indicate that instances launched into the subnet should be assigned a public IP address. Default is `false`.
 
 ~~~
 resource "aws_subnet" "subnet1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
}
~~~


- Provides a resource to create a VPC routing table.
    - `vpc_id` (Required) The VPC ID.
    - `route` (Optional) A list of route objects. Their keys are documented below. This argument is processed in attribute-as-blocks mode. This means that omitting this argument is interpreted as ignoring any existing routes. To remove all managed routes an empty list should be specified.
    - `cidr_block` (Optional) The IPv4 CIDR block for the subnet.
    - `gateway_id`  (Optional) Identifier of a VPC internet gateway or a virtual private gateway.

~~~
# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
~~~

- Provides a resource to create an association between a route table and a subnet or a route table and an internet gateway or virtual private gateway.
    - `subnet_id` (Optional) The subnet ID to create an association. Conflicts with `gateway_id`.
    - `route_table_id` (Required) The ID of the routing table to associate with.

~~~
resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}
~~~


- Provides a security group resource.
    - `name` (Optional, Forces new resource) Name of the security group. If omitted, Terraform will assign a random, unique name.
    - `vpc_id` (Optional, Forces new resource) VPC ID.
    - `from_port` (Required) Start port (or ICMP type number if protocol is icmp or icmpv6).
    - `to_port` (Required) End range port (or ICMP code if protocol is icmp).
    - `protocol` (Required) Protocol.
    - `cidr_blocks` (Optional) List of CIDR blocks.

~~~
# SECURITY GROUPS #
# Nginx security group 
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = aws_vpc.vpc.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
~~~

- Provides an EC2 instance resource. This allows instances to be created, updated, and deleted. Instances also support provisioning.
    - `ami` (Optional) AMI to use for the instance. Required unless launch_template is specified and the Launch Template specifes an AMI. If an AMI is specified in the Launch Template, setting ami will override the AMI specified in the Launch Template.
    - `instance_type` (Optional) The instance type to use for the instance. Updates to this field will trigger a stop/start of the EC2 instance.
    - `subnet_id` (Optional) VPC Subnet ID to launch in.
    - `vpc_security_group_ids` (Optional, VPC only) A list of security group IDs to associate with.
    - `user_data` (Optional) User data to provide when launching the instance. Do not pass gzip-compressed data via this argument


~~~
# INSTANCES #
resource "aws_instance" "nginx1" {
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
  instance_type          = var.aws_instance_type.small
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.nginx_profile.name
  depends_on             = [aws_iam_role_policy.allow_s3_all]

  user_data = <<EOF
#! /bin/bash
sudo amazon-linux-extras install -y nginx1
sudo service nginx start
aws s3 cp s3://${aws_s3_bucket.web_bucket.id}/website/index.html /home/ec2-user/index.html
aws s3 cp s3://${aws_s3_bucket.web_bucket.id}/website/Globo_logo_Vert.png /home/ec2-user/Globo_logo_Vert.png
sudo rm /usr/share/nginx/html/index.html
sudo cp /home/ec2-user/index.html /usr/share/nginx/html/index.html
sudo cp /home/ec2-user/Globo_logo_Vert.png /usr/share/nginx/html/Globo_logo_Vert.png
EOF
}
~~~

OBS: EOF (End Of File) is the way to specify a block of text that should not be interpreted. It must be passed directly to the argument.

------------------
### Deploying the application:  
1. Type in the VSCode terminal (in your project directory) the command **`terraform init`**. Terraform will look for configuration files within the current working directory and examine them to see if they need any plugins. If it needs it, it will try to download these plugins from the Public Terraform Registry unless an alternate path is specified.
2. Type **`terraform plan -out XXXXX.tfplan`**. Where the `-out XXXXX.tfplan` command writes the plan to a specific XXXXX input file. Terraform examines the current configuration and the contents of its state data, determines the differences between the two files, and makes a plan to update your target environment to match the desired configuration. Terraform will print the plan for you to review and you can check the changes Terraform wants to make. All modifications added will be with the + symbol in green color. If everything is ok, type `yes`.
3. Type **`terraform apply XXXXX.tfplan`**. Once the planning is done, resources will be created or modified in the target environment and then the state data will be updated to reflect the changes. If we run the terraform plan or apply it without any modification, Terraform will inform you that no changes are needed as the configuration and state data match.
4. (RECOMMENDED) Type **`terraform destroy`** to destroy all infrastructure created. As the object of the project is study only, the resources created can generate costs in AWS if they are maintained. To avoid unwanted charges, perform step 4.

OBS: Run VScode as administrator to avoid terminal directory access issues.

------------------
### Results 

EC2 instance was created in AWS as defined resources.

![EC2-console-instance](/images/ec2-console-instance.PNG)
![EC2-console-instance-security](/images/ec2-console-instance-security.PNG)


