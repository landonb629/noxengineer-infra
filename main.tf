locals {
  bucket_name = "noxengineer-deployment-prod"
}

data "aws_iam_policy_document" "cloudfront_oac_s3" {
  statement {
    sid = "allowCloudfront"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values = [module.cloudfront_distro.cloudfront_distribution_arn]
    }
    actions = ["s3:GetObject"]
    resources = ["${module.s3-bucket.s3_bucket_arn}/*"]
  }
}

module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = local.bucket_name
  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = true
  attach_policy = true
  restrict_public_buckets = false
  website = {
    index_document = "index.html"
  }
  policy = data.aws_iam_policy_document.cloudfront_oac_s3.json
}

module "cloudfront_distro" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "4.1.0"

  aliases = ["noxengineer.com", "www.noxengineer.com"]
  comment = "noxengineer CF distro"
  enabled = true
  default_root_object = "index.html"
  create_origin_access_control = true
  origin_access_control = {
    s3_oac = {
      description = "noxengineer oac"
      origin_type = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }
  origin = {
    noxengineer = {
      domain_name = module.s3-bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac"
    }
  }
  viewer_certificate = {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method = "sni-only"
  }
  default_cache_behavior = {
    target_origin_id = "noxengineer"
    viewer_protocol_policy = "https-only"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
  }
  custom_error_response = [
    {
      error_code = 404
      response_code = 200
      repsonse_page_path = "/index.html"
    },
    {
      error_code = 403
      response_code = 200
      response_page_path = "/index.html"
    }
  ]
  depends_on = [ module.acm ]
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.1.1"

  domain_name = "noxengineer.com"
  zone_id = "Z02327713O62WJSZVOOKF"
  validation_method = "DNS"
  wait_for_validation = true
  subject_alternative_names = [
    "noxengineer.com",
    "www.noxengineer.com"
  ]
}

resource "aws_route53_record" "www" {
  zone_id = "Z02327713O62WJSZVOOKF"
  name = "www.noxengineer.com"
  type = "CNAME"
  ttl = 60
  records = [module.cloudfront_distro.cloudfront_distribution_domain_name]
}

resource "aws_route53_record" "nox" {
  zone_id = "Z02327713O62WJSZVOOKF"
  name = "noxengineer.com"
  type = "A"
   alias {
    name = module.cloudfront_distro.cloudfront_distribution_domain_name
    zone_id = module.cloudfront_distro.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}