# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                       SCALEWAY STORAGE TERRAFORM MODULE                      ║
# ║                                                                              ║
# ║  This module is split by domain:                                             ║
# ║                                                                              ║
# ║    object-storage.tf  S3-compatible buckets, ACLs, website, lock, policies,  ║
# ║                       and object uploads.                                    ║
# ║    block-storage.tf   Network-attached SSD volumes and snapshots, including  ║
# ║                       QCOW2 export/import to/from Object Storage.            ║
# # ║    locals.tf          Bucket/volume/snapshot count expansion, block tags.    ║
# ║    variables.tf       Input variables with full validation.                  ║
# ║    outputs.tf         Module outputs grouped by resource.                    ║
# ║    versions.tf        Terraform/OpenTofu and provider version constraints.   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
