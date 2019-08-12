resource "aws_acm_certificate" "default" {
  count                     = "${var.enabled ? 1 : 0}"
  domain_name               = "${var.domain_name}"
  validation_method         = "${var.validation_method}"
  subject_alternative_names = "${var.subject_alternative_names}"
  tags                      = "${var.tags}"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  zone_name                         = "${var.zone_name == "" ? var.domain_name : var.zone_name}"
  process_domain_validation_options = "${var.enabled == "true" && var.process_domain_validation_options == "true" && var.validation_method == "DNS"}"
  domain_validation_options         = ["${concat(flatten(aws_acm_certificate.default.*.domain_validation_options), list(map()))}"]
}

data "aws_route53_zone" "default" {
  count        = "${local.process_domain_validation_options == "true" ? 1 : 0}"
  name         = "${local.zone_name}."
  private_zone = false
}

resource "aws_route53_record" "default" {
  count           = "${local.process_domain_validation_options == "true" ? length(var.subject_alternative_names) + 1 : 0}"
  zone_id         = "${join("", data.aws_route53_zone.default.*.zone_id)}"
  ttl             = "${var.ttl}"
  allow_overwrite = true
  name            = "${lookup(local.domain_validation_options[count.index], "resource_record_name", "")}"
  type            = "${lookup(local.domain_validation_options[count.index], "resource_record_type", "")}"
  records         = ["${lookup(local.domain_validation_options[count.index], "resource_record_value", "")}"]
}

resource "aws_acm_certificate_validation" "default" {
  count                   = "${local.process_domain_validation_options == "true" && var.wait_for_certificate_issued == "true" ? 1 : 0}"
  certificate_arn         = "${join("", aws_acm_certificate.default.*.arn)}"
  validation_record_fqdns = "${aws_route53_record.default.*.fqdn}"
}
