resource "kubernetes_persistent_volume_claim" "minio-dump-pvc" {
    metadata {
        name = "minio-dump-pvc"
    }
    spec {
        storage_class_name = "local-storage"
        access_modes = ["ReadWriteMany"]
        resources {
            requests = {
                storage = "3Gi"
            }
        }
    }

    wait_until_bound = false

    timeouts {
        create = "1m"
    }
}
