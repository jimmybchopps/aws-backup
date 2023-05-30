provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "vpc-test" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"
  tags = var.env_tags
}

resource "aws_subnet" "test-subnet" {
  vpc_id     = "${aws_vpc.vpc-test.id}"
  cidr_block = "10.10.1.0/24"
  availability_zone = var.aws_zone
  tags = var.env_tags
  depends_on = [ aws_vpc.vpc-test ]
}

resource "aws_subnet" "test-subnet2" {
  vpc_id     = "${aws_vpc.vpc-test.id}"
  cidr_block = "10.10.2.0/24"
  availability_zone = var.aws_zone2
  tags = var.env_tags
  depends_on = [ aws_vpc.vpc-test ]
}

resource "aws_internet_gateway" "test-ig" {
  vpc_id = "${aws_vpc.vpc-test.id}"
  tags = var.env_tags
  depends_on = [ aws_vpc.vpc-test ]
}

resource "aws_route_table" "test-rt" {
  vpc_id = "${aws_vpc.vpc-test.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-ig.id}"
  }
  depends_on = [ aws_internet_gateway.test-ig ]
}

resource "aws_route_table_association" "test-rta" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-rt.id
  depends_on = [ aws_route_table.test-rt ]
}

resource "aws_security_group" "test-sg" {
  name = var.sg_name
  description = var.global_description
  vpc_id = "${aws_vpc.vpc-test.id}"

  // To Allow SSH Transport
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = var.env_tags
}

resource "aws_efs_file_system" "test-efs" {
  creation_token = "test-efs"

  tags = var.backup_tags
}

# Creating Mount target of EFS

resource "aws_efs_mount_target" "mount" {
  file_system_id = aws_efs_file_system.test-efs.id
  subnet_id      = aws_instance.test-ec2.subnet_id
  security_groups = [aws_security_group.test-sg.id]
}

# Creating Mount Point for EFS

resource "null_resource" "configure_nfs" {
depends_on = [aws_efs_mount_target.mount]
connection {
type     = "ssh"
user     = "ec2-user"
private_key = tls_private_key.my_key.private_key_pem
host     = aws_instance.test-ec2.public_ip
}
}

resource "aws_ebs_volume" "test-ebs" {
  availability_zone = var.aws_zone
  size              = 10
  tags = var.backup_tags
}

resource "aws_instance" "test-ec2" {
  ami = var.ec2_ami
  instance_type = var.ec2_size
  subnet_id = "${aws_subnet.test-subnet.id}"
  associate_public_ip_address = true
  key_name = var.ec2_key_name
  availability_zone = var.aws_zone

  vpc_security_group_ids = [
    aws_security_group.test-sg.id
  ]
  root_block_device {
    delete_on_termination = true
    volume_size = 25
    volume_type = "gp2"
  }
  tags = var.env_tags
  depends_on = [ aws_security_group.test-sg ]
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "pk" {
  key_name = var.ec2_key_name
  public_key = tls_private_key.pk.public_key_openssh
  tags = var.env_tags
  provisioner "local-exec" {
    command = "echo '${tls_private_key.pk.private_key_pem}' > ../access/ec2_key.pem"
  }
}

resource "aws_volume_attachment" "ebsAttach" {
    device_name = "/dev/sdh"
    volume_id = aws_ebs_volume.test-ebs.id
    instance_id = aws_instance.test-ec2.id
}

resource "aws_s3_bucket" "test-backup-bucket" {
  bucket = "choppsaws-test-backup"
}

resource "aws_s3_bucket_acl" "test-acl" {
  bucket = aws_s3_bucket.test-backup-bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "versioning_test" {
  bucket = aws_s3_bucket.test-backup-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

module "cluster" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  create = true
  name           = "test-aurora-db"
  engine         = "aurora-mysql"
  engine_version = "8.0"
  instance_class = var.rds_size
  instances = {
    one = {
      instance_class = var.rds_size
    }
  }

  master_username = var.rds_user
  master_password = var.rds_pass

  vpc_id = aws_vpc.vpc-test.id
  create_db_subnet_group = true
  subnets = [aws_subnet.test-subnet.id, aws_subnet.test-subnet2.id]
  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10
  skip_final_snapshot = true

  tags = var.backup_tags
}

output "ec2_ip" {
  value = ["${aws_instance.test-ec2.*.public_ip}"]
}
