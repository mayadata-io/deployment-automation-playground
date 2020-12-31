provider "kubernetes" {}

resource "kubernetes_pod" "minio-pod-resource" {
    metadata {
        generate_name = "minio-pod-"
        labels = {
            name = "minio-pod"
        }
    }
    spec {
        container {
            image = "minio/minio"
            name = "minio-container"

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

            command = ["minio"]

            args = ["server", "/data"]

            port {
                container_port = 9000
            }
        }
        restart_policy = "OnFailure"
    }
}

resource "kubernetes_service" "minio-service-resource" {
    metadata {
        name = "minio-service"
    }
    spec {
        type = "LoadBalancer"
        selector = {
            name = "minio-pod"
        }
        port {
            port = 9000
            target_port = 9000
        }
    }
}

data "kubernetes_service" "minio-service-ip-data-source" {
    metadata {
        name = "minio-service"
    }

    depends_on = ["kubernetes_service.minio-service-resource"]
}
    
output "minio_service_ingress_ip" {
    value = "${data.kubernetes_service.minio-service-ip-data-source.load_balancer_ingress.0.hostname}"
}