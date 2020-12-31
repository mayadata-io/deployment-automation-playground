terraform {
    required_providers {
        kubernetes = {
            source = "hashicorp/kubernetes"
        }
    }
}

module "deploy-minio" {
    source = "./deploy-minio/"
}

locals {
    globals = {
        minio_service_ingress_ip = "${module.deploy-minio.minio_service_ingress_ip}"
    }
}

module "deploy-pvc" {
    source = "./deploy-pvc"
}

module "deploy-minio-push-and-pull-containers" {
    source = "./deploy-minio-push-and-pull-containers"

    globals = local.globals
}

    