# WAFv2 REGIONAL — ALB 앞단 (CloudFront 였다면 CLOUDFRONT + us-east-1).
# 정책: AWS Managed Rules 3종 + rate-based rule. ZETI 시연 범위에 충분.

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_prefix}-waf-acl"
  description = "ZETI WAF - AWS managed core + rate limit"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 1) Common Rule Set — XSS, LFI, etc.
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_prefix}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 2) Known Bad Inputs — 알려진 공격 패턴
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_prefix}-KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # 3) SQLi
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_prefix}-SQLi"
      sampled_requests_enabled   = true
    }
  }

  # 4) Rate-based — IP 당 5분 윈도우 임계치 초과 시 BLOCK
  rule {
    name     = "RateLimitPerIP"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_prefix}-RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_prefix}-waf-acl"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.project_prefix}-waf-acl" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
