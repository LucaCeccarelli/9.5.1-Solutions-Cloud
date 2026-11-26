# Lab 5: network part (student 6, with student 7)

## What it creates

- State in S3: `global/s3/student_6_7/network.tfstate`
- VPC "Lab5-6" fetched with a data source (`192.168.0.0/16`)
- 3 subnets:
  - `student_6_7_Private`: `192.168.6.0/24`, zone a
  - `student_6_7_Public_a`: `192.168.7.0/24`, zone a
  - `student_6_7_Public_b`: `192.168.107.0/24`, zone b
- 2 security groups:
  - `public`: http/https from the internet
  - `internal`: http/https from `public` only
- Module `modules/alb`: load balancer on the public subnets, `/nginx` and `/tomcat` each go to their own target group

## Our choices

- Region `eu-north-1`: the Paris limit was reached. The state bucket stays in `eu-west-3`.
- Security groups are really named `student_6_7_public` / `student_6_7_internal`: names must be unique in the shared VPC.
- Private subnet in zone a: the load balancer only reaches zones where it has a subnet.
- Tomcat on port 80: `internal` only allows http/https.
- The load balancer and target groups are in this state. Student 7 reads the outputs with `terraform_remote_state` and attaches the ASGs.
