module "ec2" {
  // 歴史的経緯。既にPHP70のリソースは破棄されていて、その他のサーバのresource を使っている
  source             = "../../../modules/ec2"
  ec2                = local.ec2_variable
  zone_id            = local.zone_id
  name               = "${terraform.workspace}-php80" // phpが動作するサーバだけに使う名前
  env_name           = terraform.workspace
  provision_sg_rules = local.provision_sg_rules
  private_key        = var.private_key
}
