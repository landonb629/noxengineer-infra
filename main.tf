module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = "noxengineer-deployment-prod"
  website = { 
    
  }
}