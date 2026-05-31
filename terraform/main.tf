# 모듈 와이어링 순서:
#   vpc → security_groups → ec2 (auth/api role ARN 필요)
#   ec2 의 role ARN → kms (key policy 에 grant)
#   vpc + sg-alb → alb (ACM cert 는 route53 에서 받아옴)
#   alb → waf (association)
#   alb DNS + zone → route53 (alias + ACM validation)
#
# Note: alb 가 ACM 을 의존하고, route53 가 alb 를 의존 → 순환?
#   사실 아니다. route53 는 (1) hosted_zone + ACM cert 정의, (2) ALB alias record 두 단계.
#   ALB 의 HTTPS listener 는 ACM 만 의존하면 됨. alias record 는 ALB 가 만들어진 후 생성.

module "vpc" {
  source = "./modules/vpc"

  project_prefix = var.project_prefix
  vpc_cidr       = var.vpc_cidr
  az_a           = var.az_a
  az_b           = var.az_b
}

module "security_groups" {
  source = "./modules/security_groups"

  project_prefix = var.project_prefix
  vpc_id         = module.vpc.vpc_id
}

# Route53 + ACM 먼저 — ALB HTTPS listener 가 cert ARN 의존.
# alias record 는 alb_dns_name placeholder 로 받아두면 일단 인스턴스화는 OK.
# (실제 apply 순서는 terraform 의 dependency graph 가 처리)
module "route53" {
  source = "./modules/route53"

  project_prefix = var.project_prefix
  domain_name    = var.domain_name
  alb_dns_name   = module.alb.alb_dns_name
  alb_zone_id    = module.alb.alb_zone_id
}

module "alb" {
  source = "./modules/alb"

  project_prefix      = var.project_prefix
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  alb_sg_id           = module.security_groups.alb_sg_id
  acm_certificate_arn = module.route53.acm_certificate_arn
}

module "waf" {
  source = "./modules/waf"

  project_prefix = var.project_prefix
  alb_arn        = module.alb.alb_arn
}

module "ec2" {
  source = "./modules/ec2"

  project_prefix          = var.project_prefix
  priv_web_subnet_ids     = module.vpc.priv_web_subnet_ids
  priv_app_subnet_ids     = module.vpc.priv_app_subnet_ids
  priv_monitor_subnet_ids = module.vpc.priv_monitor_subnet_ids
  nginx_sg_id             = module.security_groups.nginx_sg_id
  app_sg_id               = module.security_groups.app_sg_id
  elk_sg_id               = module.security_groups.elk_sg_id
  uba_sg_id               = module.security_groups.uba_sg_id
  tg_nginx_arn            = module.alb.tg_nginx_arn
}

module "kms" {
  source = "./modules/kms"

  project_prefix       = var.project_prefix
  auth_server_role_arn = module.ec2.auth_server_role_arn
  api_server_role_arn  = module.ec2.api_server_role_arn
}

module "rds" {
  source = "./modules/rds"

  project_prefix     = var.project_prefix
  priv_db_subnet_ids = module.vpc.priv_db_subnet_ids
  db_sg_id           = module.security_groups.db_sg_id
  kms_key_arn        = module.kms.rds_key_arn
  master_password    = var.rds_master_password
}
