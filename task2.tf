provider "aws" {
    region ="ap-south-1"
    profile = "tunuguntla"
  
}



resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "mynewvpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "mysubnet1"
  }
}

#Create Security group
resource "aws_security_group" "allow_tls2" {
  name        = "allow_tls2"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "NFSFirewall"
  }
}

resource "aws_efs_file_system" "myefs" {
  creation_token = "myUniqueEfs12"
  tags = {
    Name = "myefs"
  }
}


resource "aws_efs_mount_target" "myefsmount" {
    file_system_id = "${aws_efs_file_system.myefs.id}"
    subnet_id = "${aws_subnet.sub1.id}"
    security_groups = [ aws_security_group.allow_tls2.id ]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name = "igwmy"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "rtable"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.sub1.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

#Create EC2 instance
resource "aws_instance" "myin2" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "mykey97"
    subnet_id = "${aws_subnet.sub1.id}"
    vpc_security_group_ids = [ "${aws_security_group.allow_tls2.id}" ]
    user_data = <<-EOF
      #! /bin/bash
      
       sudo yum install httpd -y
       sudo systemctl start httpd 
       sudo systemctl enable httpd
       sudo rm -rf /var/www/html/*
       sudo yum install -y amazon-efs-utils
       sudo apt-get -y install amazon-efs-utils
       sudo yum install -y nfs-utils
       sudo apt-get -y install nfs-common
       sudo file_system_id_1="${aws_efs_file_system.myefs.id}"
       sudo efs_mount_point_1="/var/www/html"
       sudo mkdir -p "$efs_mount_point_1"
       sudo test -f "/sbin/mount.efs" && echo "$file_system_id_1:/ $efs_mount_point_1 efs tls,_netdev" >> /etc/fstab || echo "$file_system_id_1.efs.ap-south-1.amazonaws.com:/$efs_mount_point_1 nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
       sudo test -f "/sbin/mount.efs" && echo -e "\n[client-info]\nsource=liw"   >> /etc/amazon/efs/efs-utils.conf
       sudo mount -a -t efs,nfs4 defaults
       cd /var/www/html
       sudo yum insatll git -y
       sudo mkfs.ext4 /dev/xvdf1
       sudo rm -rf /var/www/html/*
       sudo yum install git -y
       sudo git clone https://github.com/varshith97/task2.git /var/www/html
     
     EOF


    tags = {
        Name = "LinuxWorld 1"
    }
}




#Creating S3 bucket
resource "aws_s3_bucket" "MyTerraformHwaBuckket" {
  bucket = "tiger9700"
  acl    = "public-read"
}

#Uploading file to S3 bucket
resource "aws_s3_bucket_object" "object1" {
  bucket = "tiger9700"
  key    = "crop.jpeg"
  source = "crop.jpeg"
  acl = "public-read"
  content_type = "image/jpeg"
  depends_on = [
      aws_s3_bucket.MyTerraformHwaBuckket
  ]
}

#Creating Cloud-front and attching S3 buccket to it
resource "aws_cloudfront_distribution" "myCloudfront1" {
    origin {
        domain_name = "tiger9700.s3.amazonaws.com"
        origin_id   = "S3-tiger9700" 

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-tiger9700"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
    depends_on = [
        aws_s3_bucket_object.object1
    ]
}
