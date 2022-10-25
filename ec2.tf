


# EC2 public

resource "aws_instance" "public" {
  ami           = var.redhat_image
  instance_type = "t2.micro"

  key_name             = "is-chenjie"
  subnet_id            = aws_subnet.public.id
  # user_data            = file("user-data.sh")
  iam_instance_profile = "dev-interview-iam-node"

  vpc_security_group_ids = [aws_security_group.public.id]

  tags = {
    Name = "${var.resource_prefix}-ec2-pub-01"
  }
}

resource "aws_eip" "ec2" {
  instance = aws_instance.public.id
  vpc      = true
}


# EC2 private

resource "aws_instance" "private" {
  ami           = var.redhat_image
  instance_type = "t2.micro"

  key_name             = "is-chenjie"
  subnet_id            = aws_subnet.private.id
  user_data            = file("user-data.sh")
  iam_instance_profile = "dev-interview-iam-node"

  vpc_security_group_ids = [aws_security_group.private.id]

  tags = {
    Name = "${var.resource_prefix}-ec2-pvt-01"
  }
}
