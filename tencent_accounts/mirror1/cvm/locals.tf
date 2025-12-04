locals {
  region  = "ap-northeast-1"
  zone_id = "Z0934766H3FKKG3636XB"

  provision_sg_rules = {
    "FROM_TECHCROSS" = {
      ip   = ["13.112.23.70/32", "160.86.227.150/32", "203.189.48.119/32", "49.212.17.172/32", "160.86.227.149/32", "160.86.227.151/32", "118.238.252.222/32", ]
      port = [22]
    },
    "FROM_TECHCROSS_NEW_OFFICE" = {
      ip   = ["182.169.23.3/32"]
      port = [22]
    },
    "FROM_SEEDS" = {
      ip   = ["3.114.147.188/32", "210.171.136.254/32"]
      port = [22]
    },
    "FROM_Q_ACE" = {
      ip   = ["221.188.13.99/32", "114.164.225.81/32"]
      port = [22]
    },
    "FROM_JENKINS" = {
      ip   = ["54.238.21.168/32"]
      port = [22]
    }
  }

  ec2_default = {
    logging_bucket                      = "kh-staging-elb-logs"
    web-deploy_instance_type            = "t3.medium"
    batch_instance_type                 = "t3.medium"
    control_instance_type               = "t3.medium"
    redis-game-data-amzn2_instance_type = "c5.large"
    nodejs_instance_type                = "t3.small"
    nodejs_instance_core_count          = "2"
    nodejs_count                        = "1"
    provision_instance_type             = "t3.large"
    provision_key_name                  = "provision-key-pair"
    native-update_instance_type         = "t3.medium"
    certificate_arn                     = "arn:aws:acm:ap-northeast-1:185860645449:certificate/41cc4c8d-033b-4532-ae6b-286b4946d761"
    nginx-img-amzn2_instance_type       = "t3.medium"
    nginx-img-amzn2_ami_name            = "kh-shared-prestage3-nginx-img-amzn2-20241030"
    provision_instance_profile          = "kh-stageX-provision"
    create_web_deploy                   = false
  }

  ec2_php80 = {
    mirror1 = merge(local.ec2_default, {
      web-deploy_instance_type      = "t4g.medium"
      web-deploy_ami_name           = "kh-mirror1-php80-web-deploy-20250414"
      batch_ami_name                = "kh-stage1-php80-batch-01-20241218"
      control_ami_name              = "kh-mirror1-php80-control-202311070325"
      nodejs_ami_name               = "kh-mirror1-nodejs-a1"
      provision_ami_name            = "kh-mirror1-amzn2-provision-202110260657"
      native-update_ami_name        = "kh-prestage5-native-update-202403120215"
      create_web_deploy             = true
      nginx-img-amzn2_instance_type = "t3.micro"
    })
  }
  ec2_variable = lookup(local.ec2_php80, terraform.workspace, local.ec2_default)
}
