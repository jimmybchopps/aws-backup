variable "aws_region" {
    type = string
    default = "us-east-1"
}

variable "aws_zone" {
    type = string
    default = "us-east-1a"
}

variable "aws_zone2" {
    type = string
    default = "us-east-1b"
}

variable "global_description" {
    type = string
    default = "Created by Terraform"
}

variable "env_tags" {
    type = map(string)
    default = {
        "Environment" = "Test"
    }
}

variable "backup_tags" {
    type = map(string)
    default = {
        "Environment" = "Test"
        "Backups" = "Enabled"
    }
} 

variable "ec2_ami" {
    type = string
    default = "ami-00874d747dde814fa"
}

variable "ec2_size" {
    type = string
    default = "t2.micro"
}

variable "ec2_key_name" {
    type = string
    default = "test_key"
}

variable "rds_size" {
    type = string
    default = "db.t3.medium"
}

variable "rds_user" {
    type = string
    default = "sqladmin"
}

variable "rds_pass" {
    type = string
    default = "OMGthisISsoSECURE"
}

variable "my_ip" {
    type = string
    default = "67.11.10.215/32"
}

variable "sg_name" {
    type = string
    default = "test-sg"
}