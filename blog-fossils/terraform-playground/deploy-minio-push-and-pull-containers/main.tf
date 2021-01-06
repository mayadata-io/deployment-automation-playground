#terraform {
#    required_providers {
#        kubernetes = {
#            source = "hashicorp/kubernetes"
#        }
#    }
#}

variable "globals" {
    type = object({
        minio_service_ingress_ip = string
    })
}

# first resource in the module to be created
resource "time_sleep" "wait_4_minutes" {
  create_duration = "4m"
}

resource "kubernetes_job" "minio-push-and-pull-job" {
    depends_on = [time_sleep.wait_4_minutes]

    metadata {
        generate_name = "minio-push-and-pull-job-"
    }
    spec { 
        template {
            metadata {
                generate_name = "minio-push-and-pull-job-"
            }
            spec {
                init_container {
                    name = "upload-to-minio"
                    image = "watcher00090/deployment-automation-playground-upload-to-minio"
                    image_pull_policy = "IfNotPresent"
                    env {
                        name = "MINIO_SERVER_AND_PORT"
                        value = "${var.globals.minio_service_ingress_ip}:9000"
                    }
                    env {
                        name = "MINIO_ACCESS_KEY"
                        value_from {
                            secret_key_ref {
                                name = "minio-server-authentication-info"
                                key = "MINIO_ACCESS_KEY"
                            }
                        }
                    }
                    env {
                        name = "MINIO_SECRET_KEY"
                        value_from {
                            secret_key_ref {
                                name = "minio-server-authentication-info"
                                key = "MINIO_SECRET_KEY"
                            }
                        }
                    }
                    
                }
                init_container {
                    name = "sleep"
                    image = "ubuntu"
                    image_pull_policy = "IfNotPresent"
                    command = ["sleep"]
                    args = ["5"]
                }
                init_container {
                    name = "fetch-from-minio"
                    image = "watcher00090/deployment-automation-playground-fetch-from-minio"
                    image_pull_policy = "IfNotPresent"
                    volume_mount {
                        name = "minio-dump-local-pv"
                        mount_path = "/mnt/localpv-vol-0/"
                    }
                    env {
                        name = "MINIO_SERVER_AND_PORT"
                        value = "${var.globals.minio_service_ingress_ip}:9000"
                    }
                    env {
                        name = "MINIO_ACCESS_KEY"
                        value_from {
                            secret_key_ref {
                                name = "minio-server-authentication-info"
                                key = "MINIO_ACCESS_KEY"
                            }
                        }
                    }
                    env {
                        name = "MINIO_SECRET_KEY"
                        value_from {
                            secret_key_ref {
                                name = "minio-server-authentication-info"
                                key = "MINIO_SECRET_KEY"
                            }
                        }
                    }
                }
                container {
                    name = "job-complete-container"
                    image = "ubuntu"
                    command =["echo"]
                    args = ["job complete!"]
                }
                volume {
                    name = "minio-dump-local-pv"
                    persistent_volume_claim {
                        claim_name = "minio-dump-pvc"
                    }
                }
            }
        }
    }
}