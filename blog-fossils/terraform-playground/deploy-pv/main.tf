resource "kubernetes_persistent_volume" "minio-dump-local-pv" {
    metadata {
        name = "minio-dump-local-pv"
    }
    spec {
        capacity = {
            storage = "3Gi"
        }
        volume_mode = "Filesystem"
        access_modes = ["ReadWriteMany"]
        persistent_volume_reclaim_policy = "Retain"
        storage_class_name = "local-storage"
        persistent_volume_source {
            local {
                path = "/mnt/minio-dump/"
            }
        }
        node_affinity {
            required {
                node_selector_term {
                    match_expressions {
                        key = "kubernetes.io/hostname"
                        operator =  "In"
                        values = ["ip-172-20-57-85.us-east-2.compute.internal"] # hostname of the first worker
                    }
                }
            }
        }
    }
}