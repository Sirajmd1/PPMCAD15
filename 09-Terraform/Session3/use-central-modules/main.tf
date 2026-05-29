module "hvd_ec2" {
  source        = "git::https://github.com/Avinashsain/central-tf-modules.git//ec2?ref=main"
  ami_id        = "ami-00d8fc944fb171e29"
  sg_ids        = [module.hvd_sg.sg_id]
  instance_type = "t3.micro"
  instance_name = "test-instance-aryan-01"
  subnet_id     = "subnet-01ed811e6bd6d7965"

}

module "hvd_sg" {
  source = "github.com/Avinashsain/central-tf-modules//sg?ref=main"
}
