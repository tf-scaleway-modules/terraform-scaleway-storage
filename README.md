# Scaleway Storage Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]
[![Latest Release][release-badge]][release-url]

A **production-ready** Terraform/OpenTofu module for creating and managing Scaleway storage infrastructure including Object Storage (S3-compatible) and Block Storage (network-attached SSDs).

## Overview

This module provides a complete solution for managing Scaleway storage resources:
- **Object Storage**: S3-compatible buckets with lifecycle policies, static website hosting, WORM compliance, and more
- **Block Storage**: Network-attached SSD volumes and snapshots for persistent storage

It follows infrastructure-as-code best practices with extensive validation and sensible defaults.

### Key Features

#### Object Storage (S3-Compatible)

| Feature | Description |
|---------|-------------|
| **Multiple Buckets** | Create and manage multiple buckets with a single module call |
| **Bucket Count** | Create N instances of each bucket type with `count` parameter |
| **Access Control** | ACLs (private, public-read) - `public-read-write` blocked for security |
| **Versioning** | Object versioning for data protection and recovery |
| **Lifecycle Rules** | Automatic transitions to GLACIER, expiration, multipart cleanup |
| **Static Websites** | Host static websites with custom index and error pages |
| **Object Lock (WORM)** | Compliance and governance modes for regulatory requirements |
| **CORS Support** | Cross-Origin Resource Sharing for web applications |
| **Object Uploads** | Upload files or inline content during provisioning |

#### Block Storage (Network-Attached SSDs)

| Feature | Description |
|---------|-------------|
| **Block Volumes** | Network-attached SSD storage independent of Instance lifecycle |
| **High Performance** | Up to 15,000 IOPS for demanding workloads |
| **Snapshots** | Point-in-time backups for disaster recovery and cloning |
| **Flexible Sizing** | 5 GB to 10 TB per volume |
| **Zone Selection** | Deploy in any availability zone within the region |

### Expanded Bucket Keys

When you define a bucket, it gets an expanded key with a suffix:
- `count = 1` → `bucket-1` (name unchanged)
- `count = 3` → `bucket-1`, `bucket-2`, `bucket-3` (names get `-1`, `-2`, `-3`)

Always reference buckets using expanded keys in outputs, objects, and policies.

## Quick Start

### Prerequisites

- Terraform >= 1.10.7 or OpenTofu >= 1.10
- Scaleway account with API credentials configured
- Existing Scaleway project

### Examples

| Example | Description |
|---------|-------------|
| [minimal](examples/minimal/) | Simple single bucket setup |
| [complete](examples/complete/) | Full-featured example with Object Storage and Block Storage |

### Minimal Example

```hcl
module "storage" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git?ref=v1.0.0"

  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  project_name    = "my-project"

  buckets = {
    data = {
      name = "mycompany-data-bucket"
    }
  }
}

output "bucket_endpoint" {
  value = module.storage.bucket_endpoints["data-1"]  # Use expanded key
}
```

## Usage Examples

### Private Data Bucket with Lifecycle Rules

```hcl
module "storage" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = "production"
  region          = "fr-par"
  tags            = { environment = "production", managed-by = "terraform" }

  buckets = {
    logs = {
      name          = "mycompany-logs-prod"
      acl           = "private"
      versioning    = true
      force_destroy = false  # Prevent accidental deletion

      lifecycle_rules = [
        {
          id      = "archive-old-logs"
          enabled = true
          prefix  = "application/"

          # Move to cheaper storage after 30 days
          transition = [
            {
              days          = 30
              storage_class = "GLACIER"
            }
          ]

          # Delete after 1 year
          expiration = {
            days = 365
          }

          # Clean up failed uploads
          abort_incomplete_multipart_upload = {
            days_after_initiation = 7
          }
        }
      ]

      tags = { type = "logs", retention = "1year" }
    }
  }
}
```

### Static Website Hosting

```hcl
module "website" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = "websites"
  region          = "fr-par"

  buckets = {
    website = {
      name          = "mycompany-website-prod"
      acl           = "public-read"
      force_destroy = false

      website = {
        index_document = "index.html"
        error_document = "404.html"
      }

      cors_rules = [
        {
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["https://mycompany.com"]
          allowed_headers = ["*"]
          max_age_seconds = 3600
        }
      ]

      tags = { type = "website" }
    }
  }

  # Upload initial files (use expanded bucket key: "website-1")
  objects = {
    index = {
      bucket_key   = "website-1"  # Expanded key (count defaults to 1)
      key          = "index.html"
      content      = "<html><body><h1>Welcome!</h1></body></html>"
      content_type = "text/html"
      visibility   = "public-read"
    }
    robots = {
      bucket_key   = "website-1"  # Expanded key
      key          = "robots.txt"
      content      = "User-agent: *\nAllow: /"
      content_type = "text/plain"
      visibility   = "public-read"
    }
  }
}

output "website_url" {
  value = module.website.website_urls["website-1"]
}
```

### Compliance Bucket with Object Lock (WORM)

```hcl
module "compliance" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = "compliance"
  region          = "fr-par"

  buckets = {
    audit = {
      name                = "mycompany-audit-logs"
      acl                 = "private"
      versioning          = true    # Required for object lock
      object_lock_enabled = true    # Enable WORM - cannot be disabled!
      force_destroy       = false

      tags = { type = "compliance", retention = "7years" }
    }
  }

  bucket_lock_configurations = {
    audit_lock = {
      bucket_key = "audit-1"  # Use expanded bucket key
      rule = {
        default_retention = {
          mode  = "COMPLIANCE"  # Cannot be overridden by anyone
          years = 7            # 7-year retention for compliance
        }
      }
    }
  }
}
```

### Multi-Bucket Production Setup

```hcl
module "storage" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = var.project_name
  region          = "fr-par"
  tags            = { environment = var.environment }

  buckets = {
    # Application data (creates: data-1)
    data = {
      name          = "${var.prefix}-data-${var.environment}"
      versioning    = true
      force_destroy = var.environment != "production"
      tags          = { type = "data" }
    }

    # Static assets (creates: assets-1)
    assets = {
      name          = "${var.prefix}-assets-${var.environment}"
      acl           = "public-read"
      force_destroy = var.environment != "production"
      tags          = { type = "assets" }
    }

    # Backups (creates: backup-1)
    backup = {
      name          = "${var.prefix}-backup-${var.environment}"
      versioning    = true
      force_destroy = false

      lifecycle_rules = [{
        id      = "cleanup"
        enabled = true
        abort_incomplete_multipart_upload = {
          days_after_initiation = 1
        }
      }]

      tags = { type = "backup" }
    }
  }

  # Note: For simple public read access, use acl = "public-read" instead of policies
  # Bucket policies with Version 2023-04-17 require explicit permissions for ALL operations
  # A policy with only Principal:"*" will block Terraform from managing the bucket
}
```

### Block Storage Volumes

```hcl
module "storage" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = "production"
  region          = "fr-par"

  # Block Storage Volumes
  block_volumes = {
    # Single database volume (creates: database-1)
    database = {
      name            = "postgresql-data"
      size_in_gb      = 100
      iops            = 15000  # High performance for database
      zone            = "fr-par-1"
      prevent_destroy = true   # Document production intent
      tags            = ["database", "production"]
    }

    # Multiple app volumes (creates: app-1, app-2, app-3)
    app = {
      name       = "app-data"
      count      = 3           # Create 3 volumes
      size_in_gb = 50
      iops       = 5000        # Standard performance
      zone       = "fr-par-1"
      tags       = ["application", "production"]
    }
  }

  # Create snapshots for backup
  # Note: volume_key must use expanded key format
  block_snapshots = {
    database_backup = {
      name       = "postgresql-backup-initial"
      volume_key = "database-1"  # Expanded key (count=1 → database-1)
      tags       = ["backup", "database"]
    }

    # Create 3 snapshots for app volumes
    app_backup = {
      count      = 3
      volume_key = "app-1"       # Snapshot the first app volume
      tags       = ["backup", "app"]
    }
  }
}

output "database_volume_id" {
  value = module.storage.block_volume_ids["database-1"]  # Expanded key
}

output "app_volume_ids" {
  value = {
    app_1 = module.storage.block_volume_ids["app-1"]
    app_2 = module.storage.block_volume_ids["app-2"]
    app_3 = module.storage.block_volume_ids["app-3"]
  }
}
```

### Block Storage from Snapshot (Cloning)

```hcl
module "storage" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/scaleway-storage.git"

  organization_id = var.scw_organization_id
  project_name    = "staging"
  region          = "fr-par"

  block_volumes = {
    # Create volume from existing snapshot for testing
    database_clone = {
      name        = "postgresql-staging"
      size_in_gb  = 100
      iops        = 5000
      zone        = "fr-par-1"
      snapshot_id = "fr-par-1/11111111-1111-1111-1111-111111111111"  # Source snapshot
      tags        = ["database", "staging"]
    }
  }
}
```

# Example bucket policy (use with caution - see Security section):
# bucket_policies = {
#   assets_cdn = {
#     bucket_key = "assets-1"  # Must use expanded key
#     policy = jsonencode({
#       Version = "2023-04-17"  # Scaleway version, NOT AWS "2012-10-17"
#       Id      = "CDNAccess"
#       Statement = [
#         {
#           Sid       = "TerraformAccess"
#           Effect    = "Allow"
#           Principal = { SCW = "user_id:<YOUR_USER_ID>" }  # Your Scaleway user
#           Action    = "s3:*"
#           Resource  = ["${var.prefix}-assets-${var.environment}", "${var.prefix}-assets-${var.environment}/*"]
#         },
#         {
#           Sid       = "PublicRead"
#           Effect    = "Allow"
#           Principal = "*"
#           Action    = "s3:GetObject"
#           Resource  = "${var.prefix}-assets-${var.environment}/*"
#         }
#       ]
#     })
#   }
# }
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Scaleway Object Storage                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │    Bucket    │  │    Bucket    │  │    Bucket    │           │
│  │   (data)     │  │   (assets)   │  │   (backup)   │           │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤           │
│  │ • Versioning │  │ • Public ACL │  │ • Lifecycle  │           │
│  │ • Private    │  │ • CORS       │  │ • Versioning │           │
│  │ • Lifecycle  │  │ • Policy     │  │ • Private    │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                 │                 │                    │
│         ▼                 ▼                 ▼                    │
│  ┌────────────────────────────────────────────────────┐         │
│  │              S3-Compatible API Endpoint             │         │
│  │         https://s3.fr-par.scw.cloud                │         │
│  └────────────────────────────────────────────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Scaleway Block Storage                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   Volume     │  │   Volume     │  │   Snapshot   │           │
│  │  (database)  │  │   (logs)     │  │   (backup)   │           │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤           │
│  │ • 15K IOPS   │  │ • 5K IOPS    │  │ • Source:    │           │
│  │ • 100 GB     │  │ • 50 GB      │  │   database   │           │
│  │ • fr-par-1   │  │ • fr-par-1   │  │ • fr-par-1   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                 │                 ▲                    │
│         ▼                 ▼                 │                    │
│  ┌────────────────────────────────┐        │                    │
│  │     Attach to Instances        │────────┘                    │
│  │   (via scaleway_instance_*)    │   (restore/clone)           │
│  └────────────────────────────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## S3 Compatibility

Scaleway Object Storage is fully S3-compatible. Use standard S3 tools and SDKs:

### Endpoint Reference

| Type | Pattern | Example |
|------|---------|---------|
| API | `https://s3.<region>.scw.cloud` | `https://s3.fr-par.scw.cloud` |
| Bucket | `https://<bucket>.s3.<region>.scw.cloud` | `https://mydata.s3.fr-par.scw.cloud` |
| Website | `https://<bucket>.s3-website.<region>.scw.cloud` | `https://mysite.s3-website.fr-par.scw.cloud` |

### AWS CLI Configuration

```bash
# Configure endpoint
aws configure set s3.endpoint_url https://s3.fr-par.scw.cloud
aws configure set default.region fr-par

# Or use environment variables
export AWS_ENDPOINT_URL_S3=https://s3.fr-par.scw.cloud
export AWS_REGION=fr-par

# List buckets
aws s3 ls

# Sync files
aws s3 sync ./dist s3://my-bucket/
```

### Terraform S3 Backend

```hcl
terraform {
  backend "s3" {
    bucket                      = "my-terraform-state"
    key                         = "infrastructure/terraform.tfstate"
    region                      = "fr-par"
    endpoint                    = "https://s3.fr-par.scw.cloud"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | 2.65.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [scaleway_block_snapshot.imported](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/block_snapshot) | resource |
| [scaleway_block_snapshot.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/block_snapshot) | resource |
| [scaleway_block_volume.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/block_volume) | resource |
| [scaleway_object.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object) | resource |
| [scaleway_object_bucket.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object_bucket) | resource |
| [scaleway_object_bucket_acl.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object_bucket_acl) | resource |
| [scaleway_object_bucket_lock_configuration.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object_bucket_lock_configuration) | resource |
| [scaleway_object_bucket_policy.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object_bucket_policy) | resource |
| [scaleway_object_bucket_website_configuration.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/object_bucket_website_configuration) | resource |
| [scaleway_account_project.project](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/account_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_block_snapshots"></a> [block\_snapshots](#input\_block\_snapshots) | Map of Block Storage snapshots to create.<br/><br/>Snapshots are point-in-time copies of Block Storage volumes.<br/>Use for backups, disaster recovery, or creating new volumes.<br/><br/>SNAPSHOT CONFIGURATION:<br/>───────────────────────<br/>name       : (Optional) Snapshot name, auto-generated if not provided<br/>count      : (Optional) Number of snapshot instances to create (default: 1)<br/>volume\_key : (Required if no import) Reference to expanded volume key (e.g., "database-1")<br/>zone       : (Optional) Availability Zone (defaults to volume's zone)<br/>tags       : (Optional) Tags for the snapshot<br/><br/>EXPORT TO OBJECT STORAGE:<br/>─────────────────────────<br/>Export snapshots as QCOW2 files to Object Storage for offsite backup.<br/>export = {<br/>  bucket = "my-backup-bucket"   # Bucket name (must exist)<br/>  key    = "snapshots/db.qcow2" # Object key/path<br/>}<br/><br/>IMPORT FROM OBJECT STORAGE:<br/>───────────────────────────<br/>Create snapshot from QCOW2 file in Object Storage (instead of volume).<br/>import = {<br/>  bucket = "my-backup-bucket"   # Bucket name<br/>  key    = "snapshots/db.qcow2" # Object key/path<br/>}<br/>Note: When using import, volume\_key is not required.<br/><br/>EXPANDED KEYS:<br/>──────────────<br/>When count > 1, snapshots are created with expanded keys:<br/>- count = 1 → snapshot-1<br/>- count = 3 → snapshot-1, snapshot-2, snapshot-3<br/><br/>USE CASES:<br/>──────────<br/>- Regular backups exported to Object Storage<br/>- Disaster recovery with offsite QCOW2 files<br/>- Cross-zone/region migration via Object Storage<br/>- Creating volumes from archived snapshots | <pre>map(object({<br/>    name       = optional(string)<br/>    count      = optional(number, 1)<br/>    volume_key = optional(string) # Required if no import block<br/>    zone       = optional(string)<br/>    tags       = optional(list(string), [])<br/><br/>    # Export snapshot to Object Storage as QCOW2<br/>    export = optional(object({<br/>      bucket = string # Bucket name to export to<br/>      key    = string # Object key/path (e.g., "backups/snapshot.qcow2")<br/>    }))<br/><br/>    # Import snapshot from Object Storage QCOW2 (alternative to volume_key)<br/>    import = optional(object({<br/>      bucket = string # Bucket name to import from<br/>      key    = string # Object key/path (e.g., "backups/snapshot.qcow2")<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_block_volumes"></a> [block\_volumes](#input\_block\_volumes) | Map of Block Storage volumes to create.<br/><br/>Block volumes are network-attached SSD storage that can be attached to<br/>Scaleway Instances. They persist independently of Instances and can be<br/>moved between Instances in the same Availability Zone.<br/><br/>VOLUME CONFIGURATION:<br/>─────────────────────<br/>name            : (Optional) Volume name, auto-generated if not provided<br/>count           : (Optional) Number of volume instances to create (default: 1)<br/>size\_in\_gb      : (Required) Volume size in GB (minimum 5 GB)<br/>iops            : (Required) IOPS performance tier - 5000 or 15000<br/>zone            : (Optional) Availability Zone (defaults to fr-par-1)<br/>snapshot\_id     : (Optional) Create volume from existing snapshot<br/>prevent\_destroy : (Optional) Prevent accidental deletion (default: false)<br/>tags            : (Optional) Tags for the volume<br/><br/>IOPS TIERS:<br/>───────────<br/>5000  : Standard performance, suitable for most workloads<br/>15000 : High performance, for databases and I/O intensive applications<br/>        Requires Instance with at least 3 GiB/s block bandwidth<br/><br/>EXPANDED KEYS:<br/>──────────────<br/>When count > 1, volumes are created with expanded keys:<br/>- count = 1 → volume-1<br/>- count = 3 → volume-1, volume-2, volume-3<br/><br/>IMPORTANT NOTES:<br/>────────────────<br/>- IOPS cannot be changed after volume creation<br/>- Volume must be in same zone as Instance to attach<br/>- Minimum size is 5 GB<br/>- Set prevent\_destroy = true in production to avoid accidental deletion | <pre>map(object({<br/>    name            = optional(string)<br/>    count           = optional(number, 1)<br/>    size_in_gb      = number<br/>    iops            = number<br/>    zone            = optional(string, "fr-par-1")<br/>    snapshot_id     = optional(string)<br/>    prevent_destroy = optional(bool, false)<br/>    tags            = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_bucket_lock_configurations"></a> [bucket\_lock\_configurations](#input\_bucket\_lock\_configurations) | Map of object lock configurations for WORM compliance.<br/><br/>Object lock prevents object deletion or modification for a retention period.<br/>IMPORTANT: The bucket must have object\_lock\_enabled = true.<br/><br/>LOCK MODES:<br/>───────────<br/>GOVERNANCE  : Can be overridden by users with s3:BypassGovernanceRetention permission<br/>COMPLIANCE  : Cannot be overridden by anyone, including root account (irreversible!)<br/><br/>RETENTION PERIOD (specify exactly one):<br/>───────────────────────────────────────<br/>days  : Number of days to retain (1-36500)<br/>years : Number of years to retain (1-100)<br/><br/>WARNING: COMPLIANCE mode with long retention can make data permanently<br/>immutable. Test thoroughly in non-production environments first. | <pre>map(object({<br/>    bucket_key = string<br/>    rule = object({<br/>      default_retention = object({<br/>        mode  = string<br/>        days  = optional(number)<br/>        years = optional(number)<br/>      })<br/>    })<br/>  }))</pre> | `{}` | no |
| <a name="input_bucket_policies"></a> [bucket\_policies](#input\_bucket\_policies) | Map of bucket policies to apply.<br/><br/>Policies provide fine-grained access control using IAM-style JSON documents.<br/>More flexible than ACLs for complex access patterns.<br/><br/>POLICY STRUCTURE:<br/>─────────────────<br/>bucket\_key : Reference to bucket key in var.buckets<br/>policy     : JSON policy document (use jsonencode() for safety)<br/><br/>POLICY DOCUMENT FORMAT (Scaleway S3-compatible):<br/>────────────────────────────────────────────────<br/>{<br/>  "Version": "2023-04-17",<br/>  "Id": "MyPolicy",<br/>  "Statement": [<br/>    {<br/>      "Sid": "UniqueStatementId",<br/>      "Effect": "Allow",<br/>      "Principal": "*" \| { "SCW": "user\_id:<USER\_ID>" },<br/>      "Action": ["s3:GetObject", "s3:PutObject", ...],<br/>      "Resource": ["<bucket-name>/*"]<br/>    }<br/>  ]<br/>}<br/><br/>IMPORTANT NOTES:<br/>────────────────<br/>- Use Version "2023-04-17" (Scaleway's current version, NOT AWS's "2012-10-17")<br/>- Resource format is "<bucket-name>/*" (NOT "arn:scw:s3:::bucket-name/*")<br/>- With 2023-04-17, only explicitly allowed actions are permitted (implicit deny)<br/>- A policy with only Principal:"*" will block your Terraform user from managing the bucket<br/>- Always include your user\_id/application\_id with full S3 permissions<br/><br/>COMMON ACTIONS:<br/>───────────────<br/>s3:GetObject       - Download objects<br/>s3:PutObject       - Upload objects<br/>s3:DeleteObject    - Delete objects<br/>s3:ListBucket      - List bucket contents<br/>s3:GetBucketPolicy - Read bucket policy | <pre>map(object({<br/>    bucket_key = string<br/>    policy     = string<br/>  }))</pre> | `{}` | no |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Map of object storage buckets to create.<br/><br/>Each bucket key becomes a reference for other resources (policies, objects).<br/>Bucket names must be globally unique across all Scaleway users.<br/><br/>BUCKET CONFIGURATION OPTIONS:<br/>─────────────────────────────<br/>name                : (Required) Globally unique bucket name<br/>count               : Number of bucket instances to create (default: 1)<br/>acl                 : Access control - private, public-read, authenticated-read (public-read-write blocked for security)<br/>force\_destroy       : Allow deletion of non-empty bucket (default: false)<br/>object\_lock\_enabled : Enable WORM compliance - cannot be disabled once enabled<br/>versioning          : Keep multiple versions of objects<br/>tags                : Additional tags for this bucket<br/><br/>CORS RULES (for web browser access):<br/>────────────────────────────────────<br/>allowed\_headers : Headers allowed in preflight requests (default: ["*"])<br/>allowed\_methods : HTTP methods allowed (GET, PUT, POST, DELETE, HEAD)<br/>allowed\_origins : Origins allowed to make requests<br/>expose\_headers  : Headers exposed to browser<br/>max\_age\_seconds : Preflight cache duration (default: 3600)<br/><br/>LIFECYCLE RULES (automatic object management):<br/>──────────────────────────────────────────────<br/>id         : Unique rule identifier<br/>enabled    : Whether rule is active (default: true)<br/>prefix     : Apply to objects with this prefix (empty = all)<br/>expiration : Auto-delete after N days<br/>transition : Move to storage class (GLACIER, ONEZONE\_IA) after N days<br/>abort\_incomplete\_multipart\_upload : Clean up failed uploads<br/><br/>WEBSITE HOSTING:<br/>────────────────<br/>index\_document : Default page (e.g., "index.html")<br/>error\_document : Error page (default: "error.html") | <pre>map(object({<br/>    # Core bucket settings<br/>    name                = string<br/>    count               = optional(number, 1) # Number of buckets to create (appends -1, -2, etc. to name)<br/>    acl                 = optional(string, "private")<br/>    force_destroy       = optional(bool, false)<br/>    object_lock_enabled = optional(bool, false)<br/>    versioning          = optional(bool, false)<br/>    tags                = optional(map(string), {})<br/><br/>    # CORS configuration for web access<br/>    cors_rules = optional(list(object({<br/>      allowed_headers = optional(list(string), ["*"])<br/>      allowed_methods = list(string)<br/>      allowed_origins = list(string)<br/>      expose_headers  = optional(list(string), [])<br/>      max_age_seconds = optional(number, 3600)<br/>    })), [])<br/><br/>    # Lifecycle management rules<br/>    lifecycle_rules = optional(list(object({<br/>      id      = string<br/>      enabled = optional(bool, true)<br/>      prefix  = optional(string, "")<br/><br/>      expiration = optional(object({<br/>        days = number<br/>      }), null)<br/><br/>      transition = optional(list(object({<br/>        days          = number<br/>        storage_class = string<br/>      })), [])<br/><br/>      abort_incomplete_multipart_upload = optional(object({<br/>        days_after_initiation = number<br/>      }), null)<br/>    })), [])<br/><br/>    # Static website configuration<br/>    website = optional(object({<br/>      index_document = string<br/>      error_document = optional(string, "error.html")<br/>    }), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_objects"></a> [objects](#input\_objects) | Map of objects to upload to buckets.<br/><br/>Objects can be uploaded from local files or inline content.<br/>Use for configuration files, static assets, or initial seed data.<br/><br/>OBJECT CONFIGURATION:<br/>─────────────────────<br/>bucket\_key   : Reference to bucket key in var.buckets<br/>key          : Object path in bucket (e.g., "images/logo.png")<br/>source       : Local file path (mutually exclusive with content)<br/>content      : Inline string content (mutually exclusive with source)<br/>content\_type : MIME type (auto-detected if not specified)<br/>visibility   : private (default) or public-read<br/>tags         : Object-level tags<br/><br/>COMMON MIME TYPES:<br/>──────────────────<br/>text/html              - HTML files<br/>text/css               - CSS stylesheets<br/>text/javascript        - JavaScript files<br/>application/json       - JSON data<br/>image/png, image/jpeg  - Images<br/>application/pdf        - PDF documents | <pre>map(object({<br/>    bucket_key   = string<br/>    key          = string<br/>    source       = optional(string)<br/>    content      = optional(string)<br/>    content_type = optional(string)<br/>    visibility   = optional(string, "private")<br/>    tags         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Scaleway Organization ID.<br/><br/>The organization is the top-level entity in Scaleway's hierarchy.<br/>Find this in the Scaleway Console under Organization Settings.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Scaleway Project name where all resources will be created.<br/><br/>Projects provide logical isolation within an organization.<br/>All buckets, objects, and policies will be created in this project.<br/><br/>Naming rules:<br/>- Must start with a lowercase letter<br/>- Can contain lowercase letters, numbers, and hyphens<br/>- Must be 2-63 characters long | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Scaleway region for object storage.<br/><br/>Available regions:<br/>- fr-par: Paris, France (Europe)<br/>- nl-ams: Amsterdam, Netherlands (Europe)<br/>- pl-waw: Warsaw, Poland (Europe)<br/><br/>Choose the region closest to your users for optimal latency.<br/>Data residency requirements may also influence this choice. | `string` | `"fr-par"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Global tags applied to all resources.<br/><br/>Tags are key-value pairs for organizing and categorizing resources.<br/>Common uses:<br/>- Environment identification (environment:production)<br/>- Cost allocation (team:platform, project:website)<br/>- Automation (managed-by:terraform)<br/><br/>Format: Map of strings (e.g., {env = "prod", team = "devops"}) | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_cli_config"></a> [aws\_cli\_config](#output\_aws\_cli\_config) | AWS CLI configuration commands for connecting to Scaleway Object Storage.<br/><br/>Run these commands to configure the AWS CLI:<br/>aws configure set s3.endpoint\_url <s3\_endpoint><br/>aws configure set default.region <region> |
| <a name="output_block_snapshot_exports"></a> [block\_snapshot\_exports](#output\_block\_snapshot\_exports) | Map of snapshots configured for export to Object Storage.<br/><br/>Each entry includes:<br/>- snapshot\_id: The snapshot ID<br/>- bucket: Destination bucket name<br/>- key: Object key/path for the QCOW2 file<br/>- url: Full S3 URL to the exported file |
| <a name="output_block_snapshot_ids"></a> [block\_snapshot\_ids](#output\_block\_snapshot\_ids) | Map of expanded snapshot keys to their Scaleway resource IDs. |
| <a name="output_block_snapshots"></a> [block\_snapshots](#output\_block\_snapshots) | Map of all created Block Storage snapshots with their details.<br/><br/>Keys use expanded format (e.g., "backup-1", "backup-2").<br/>Includes both volume-based and imported snapshots.<br/><br/>Each snapshot includes:<br/>- id: Snapshot ID<br/>- name: Snapshot name<br/>- volume\_id: Source volume ID (null for imported snapshots)<br/>- zone: Availability Zone<br/>- snapshot\_key: Original snapshot key (before expansion)<br/>- index: Instance index (1, 2, 3, ...)<br/>- source: "volume" or "import"<br/>- export: Export details if configured (bucket, key) |
| <a name="output_block_volume_ids"></a> [block\_volume\_ids](#output\_block\_volume\_ids) | Map of expanded volume keys to their Scaleway resource IDs. |
| <a name="output_block_volume_names"></a> [block\_volume\_names](#output\_block\_volume\_names) | List of all block volume names created by this module. |
| <a name="output_block_volumes"></a> [block\_volumes](#output\_block\_volumes) | Map of all created Block Storage volumes with their details.<br/><br/>Keys use expanded format (e.g., "database-1", "database-2").<br/><br/>Each volume includes:<br/>- id: Volume ID (zoned format: zone/uuid)<br/>- name: Volume name<br/>- size\_in\_gb: Volume size<br/>- iops: IOPS performance tier<br/>- zone: Availability Zone<br/>- volume\_key: Original volume key (before expansion)<br/>- index: Instance index (1, 2, 3, ...) |
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Map of bucket keys to their ARN-style identifiers.<br/><br/>Format: arn:scw:s3:::<bucket-name><br/>Use in bucket policies and IAM configurations. |
| <a name="output_bucket_endpoints"></a> [bucket\_endpoints](#output\_bucket\_endpoints) | Map of bucket keys to their S3 endpoints.<br/><br/>Format: https://<bucket-name>.s3.<region>.scw.cloud<br/>Use these URLs for direct bucket access via S3 protocol. |
| <a name="output_bucket_ids"></a> [bucket\_ids](#output\_bucket\_ids) | Map of bucket keys to their Scaleway resource IDs. |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | List of all bucket names created by this module. |
| <a name="output_buckets"></a> [buckets](#output\_buckets) | Map of all created buckets with their complete details.<br/><br/>Each bucket includes:<br/>- id: Scaleway resource ID<br/>- name: Bucket name<br/>- endpoint: S3 bucket endpoint URL<br/>- api\_endpoint: S3 API endpoint<br/>- versioning\_enabled: Whether versioning is active<br/>- object\_lock\_enabled: Whether WORM is enabled<br/>- tags: Applied tags |
| <a name="output_environment_variables"></a> [environment\_variables](#output\_environment\_variables) | Environment variables for S3-compatible tools.<br/><br/>Export these in your shell or CI/CD pipeline:<br/>export AWS\_ENDPOINT\_URL\_S3=<endpoint><br/>export AWS\_REGION=<region> |
| <a name="output_lock_configurations"></a> [lock\_configurations](#output\_lock\_configurations) | Map of bucket lock configurations for WORM compliance.<br/><br/>Includes retention mode and period for each configured bucket. |
| <a name="output_object_urls"></a> [object\_urls](#output\_object\_urls) | Map of object keys to their direct URLs. |
| <a name="output_objects"></a> [objects](#output\_objects) | Map of all uploaded objects with their details.<br/><br/>Includes object location, content type, and visibility. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Scaleway Project ID where all resources are created. |
| <a name="output_region"></a> [region](#output\_region) | Region where all buckets are deployed. |
| <a name="output_s3_endpoint"></a> [s3\_endpoint](#output\_s3\_endpoint) | S3 API endpoint for the configured region.<br/><br/>Use this endpoint to configure S3-compatible clients:<br/>- AWS CLI: aws configure set s3.endpoint\_url <endpoint><br/>- AWS SDK: endpoint\_url parameter<br/>- s3cmd, rclone, etc. |
| <a name="output_website_endpoints"></a> [website\_endpoints](#output\_website\_endpoints) | Map of bucket keys to their static website endpoints.<br/><br/>Only populated for buckets with website configuration.<br/>Format: https://<bucket-name>.s3-website.<region>.scw.cloud |
| <a name="output_website_urls"></a> [website\_urls](#output\_website\_urls) | Simple map of bucket keys to website URLs (for buckets with website config). |
<!-- END_TF_DOCS -->

## Bucket Configuration Reference

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | required | Globally unique bucket name (3-63 chars) |
| `count` | number | `1` | Number of bucket instances to create (appends -1, -2, etc.) |
| `acl` | string | `"private"` | Access control: private, public-read, authenticated-read |
| `force_destroy` | bool | `false` | Allow deletion of non-empty bucket |
| `versioning` | bool | `false` | Enable object versioning |
| `object_lock_enabled` | bool | `false` | Enable WORM (cannot be disabled once enabled) |
| `tags` | map(string) | `{}` | Bucket-specific tags |
| `cors_rules` | list(object) | `[]` | CORS configuration |
| `lifecycle_rules` | list(object) | `[]` | Lifecycle management rules |
| `website` | object | `null` | Static website configuration |

> **Security Note**: `public-read-write` ACL is blocked for security reasons. Use bucket policies for controlled write access.

## Block Storage Configuration Reference

### Expanded Volume Keys

Similar to buckets, block volumes and snapshots use expanded keys:
- `count = 1` → `volume-1` (default)
- `count = 3` → `volume-1`, `volume-2`, `volume-3`

Always reference volumes using expanded keys in snapshots and outputs.

### Block Volume

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | auto | Volume name (defaults to `<key>-volume`) |
| `count` | number | `1` | Number of volume instances to create |
| `size_in_gb` | number | required | Volume size in GB (5-10000) |
| `iops` | number | required | Performance tier: `5000` (standard) or `15000` (high) |
| `zone` | string | `"fr-par-1"` | Availability zone |
| `snapshot_id` | string | `null` | Create volume from snapshot |
| `prevent_destroy` | bool | `false` | Document intent for lifecycle protection |
| `tags` | list(string) | `[]` | Resource tags |

> **Note**: `prevent_destroy` is for documentation purposes. Terraform requires literal values for lifecycle blocks - manually set `prevent_destroy = true` in the module code for production.

### Block Snapshot

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | auto | Snapshot name (defaults to `<key>-snapshot`) |
| `count` | number | `1` | Number of snapshot instances to create |
| `volume_key` | string | required* | Reference to **expanded** volume key (e.g., `database-1`) |
| `zone` | string | volume zone | Availability zone |
| `tags` | list(string) | `[]` | Resource tags |
| `export` | object | `null` | Export snapshot to Object Storage (see below) |
| `import` | object | `null` | Import snapshot from Object Storage (see below) |

*`volume_key` is required unless `import` is specified.

### Snapshot Export (to Object Storage)

Export snapshots as QCOW2 files to Object Storage for offsite backup:

```hcl
block_snapshots = {
  database_backup = {
    volume_key = "database-1"
    export = {
      bucket = "my-backup-bucket"           # Must exist
      key    = "snapshots/db-backup.qcow2"  # .qcow or .qcow2
    }
  }
}
```

### Snapshot Import (from Object Storage)

Create snapshots from QCOW2 files in Object Storage (no `volume_key` needed):

```hcl
block_snapshots = {
  restored_db = {
    zone = "fr-par-1"
    import = {
      bucket = "my-backup-bucket"
      key    = "snapshots/db-backup.qcow2"
    }
  }
}
```

### IOPS Performance Tiers

| IOPS | Tier | Use Case |
|------|------|----------|
| `5000` | Standard | General workloads, logs, media storage |
| `15000` | High Performance | Databases, high-throughput applications |

## Security Best Practices

### Production Checklist

- [ ] Set `force_destroy = false` for all production buckets
- [ ] Enable `versioning = true` for critical data
- [ ] Use `private` ACL by default; apply bucket policies for granular access
- [ ] Configure lifecycle rules to manage storage costs
- [ ] Use unique, prefixed bucket names (e.g., `companyname-env-purpose`)
- [ ] Enable object lock for compliance-critical data
- [ ] Review and restrict bucket policies regularly

### ACL vs Bucket Policies

| Use Case | Recommendation |
|----------|----------------|
| Simple public/private access | Use ACL |
| IP-based restrictions | Use Bucket Policy |
| Time-based access | Use Bucket Policy |
| Cross-account access | Use Bucket Policy |
| Specific user permissions | Use Bucket Policy |

### Object Lock Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `GOVERNANCE` | Can be overridden with special permissions | Development, testing |
| `COMPLIANCE` | Cannot be overridden by anyone | Regulatory compliance, legal hold |

> **Warning**: COMPLIANCE mode with long retention periods makes data permanently immutable. Test thoroughly before production use.

## Troubleshooting

### Common Issues

**Bucket name already exists**
```
Error: Bucket name 'mybucket' is already taken
```
Bucket names are globally unique. Add a unique prefix (company name, project ID).

**Object lock requires versioning**
```
Error: Object lock requires versioning to be enabled
```
Set `versioning = true` when using `object_lock_enabled = true`.

**Cannot delete non-empty bucket**
```
Error: Bucket is not empty
```
Set `force_destroy = true` or empty the bucket first. Not recommended for production.

**Invalid bucket name**
```
Error: Bucket name must be 3-63 characters...
```
Use lowercase letters, numbers, hyphens, and dots. Start and end with alphanumeric.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a merge request

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

Copyright 2025 - This module is independently maintained and not affiliated with Scaleway.

## Disclaimer

This module is provided "as is" without warranty of any kind. Always test in non-production environments first.

---

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io
[scaleway-badge]: https://img.shields.io/badge/Scaleway%20Provider-%3E%3D2.64-4f0599
[scaleway-url]: https://registry.terraform.io/providers/scaleway/scaleway/
[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/scaleway-storage?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/scaleway-storage/-/releases
