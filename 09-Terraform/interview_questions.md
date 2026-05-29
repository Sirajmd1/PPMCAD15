# Terraform Interview Questions
1. What is the difference between resources and data sources in Terraform

2. What is the use of Count in Terraform


3. What are dynamic blocks in Terraform
4. What are different type of Provisioners in terraform
5. What are modules in terraform
6. How do you pass output of a terraform module as input to other module

7. What is alias in terraform


8. Difference between Terraform -> vpc + ec2 instances and Ansible -> install software package on that ec2 instance (java, nginx, nginx configuration files, property file)


9. What is remote backend in terraform - 

terraform init
terraform plan
terraform apply
terraform.tfstate exists in my local

terraform.tfstate into an S3 bucket




10. How do you establish state file locking in terraform
Earlier Dynamo DB was used and now S3 native state file locking should be used


11. How do you manage a manually created resource using terraform
terraform import

12. How do you remove a resource from terraform state file
12. What are Terraform workspaces
13. What is the use of Terraform init, explain its function
14. What are locals in Terraform
local variable


15. What is the use of Terraform taint

16. How do you handle resource dependencies in Terraform?
implicit dependencies -> terraform identified it via creating a dependency graph
explicit dependencies -> 

17. Difference between count and for_each?
count is static and for_each is dynamic

18. What is the default registry of terraform?
hashicorp


19. How do you manage multiple environments (e.g., dev, staging, prod) with Terraform?
20. What is a null resource in terraform?