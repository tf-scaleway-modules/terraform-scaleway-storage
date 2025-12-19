# Scaleway Object Storage Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]
[![Latest Release][release-badge]][release-url]

A **production-ready** Terraform/OpenTofu module for creating and managing Scaleway Object Storage infrastructure with comprehensive features for enterprise deployments.

## Overview

This module provides a complete solution for managing Scaleway Object Storage resources, including buckets, lifecycle policies, static website hosting, WORM compliance, and more. It follows infrastructure-as-code best practices with extensive validation and sensible defaults.

### Key Features

| Feature | Description |
|---------|-------------|
| **Multiple Buckets** | Create and manage multiple buckets with a single module call using `for_each` |
| **Access Control** | ACLs (private, public-read, etc.) and IAM-style bucket policies |
| **Versioning** | Object versioning for data protection and recovery |
| **Lifecycle Rules** | Automatic transitions to GLACIER, expiration, multipart cleanup |
| **Static Websites** | Host static websites with custom index and error pages |
| **Object Lock (WORM)** | Compliance and governance modes for regulatory requirements |
| **CORS Support** | Cross-Origin Resource Sharing for web applications |
| **Object Uploads** | Upload files or inline content during provisioning |

## Quick Start

### Prerequisites

- Terraform >= 1.10.7 or OpenTofu >= 1.10
- Scaleway account with API credentials configured
- Existing Scaleway project

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
  value = module.storage.bucket_endpoints["data"]
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
  tags            = ["environment:production", "managed-by:terraform"]

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

      tags = ["type:logs", "retention:1year"]
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

      tags = ["type:website"]
    }
  }

  # Upload initial files
  objects = {
    index = {
      bucket_key   = "website"
      key          = "index.html"
      content      = "<html><body><h1>Welcome!</h1></body></html>"
      content_type = "text/html"
      visibility   = "public-read"
    }
    robots = {
      bucket_key   = "website"
      key          = "robots.txt"
      content      = "User-agent: *\nAllow: /"
      content_type = "text/plain"
      visibility   = "public-read"
    }
  }
}

output "website_url" {
  value = module.website.website_urls["website"]
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

      tags = ["type:compliance", "retention:7years"]
    }
  }

  bucket_lock_configurations = {
    audit_lock = {
      bucket_key = "audit"
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
  tags            = ["environment:${var.environment}"]

  buckets = {
    # Application data
    data = {
      name          = "${var.prefix}-data-${var.environment}"
      versioning    = true
      force_destroy = var.environment != "production"
      tags          = ["type:data"]
    }

    # Static assets (CDN origin)
    assets = {
      name          = "${var.prefix}-assets-${var.environment}"
      acl           = "public-read"
      force_destroy = var.environment != "production"
      tags          = ["type:assets"]
    }

    # Backups
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

      tags = ["type:backup"]
    }
  }

  # CDN policy for assets
  bucket_policies = {
    assets_cdn = {
      bucket_key = "assets"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "CDNAccess"
          Effect    = "Allow"
          Principal = "*"
          Action    = ["s3:GetObject"]
          Resource  = ["arn:scw:s3:::${var.prefix}-assets-${var.environment}/*"]
        }]
      })
    }
  }
}
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
| terraform | >= 1.10.7 |
| scaleway | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| scaleway | ~> 2.64 |

## Resources

| Name | Type |
|------|------|
| scaleway_object_bucket | resource |
| scaleway_object_bucket_acl | resource |
| scaleway_object_bucket_website_configuration | resource |
| scaleway_object_bucket_lock_configuration | resource |
| scaleway_object_bucket_policy | resource |
| scaleway_object | resource |
| scaleway_account_project | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| organization_id | Scaleway Organization ID (UUID format) | `string` | n/a | yes |
| project_name | Scaleway Project name | `string` | n/a | yes |
| region | Scaleway region: fr-par, nl-ams, pl-waw | `string` | `"fr-par"` | no |
| tags | Global tags for all resources | `list(string)` | `[]` | no |
| buckets | Map of bucket configurations | `map(object)` | `{}` | no |
| bucket_policies | Map of IAM-style bucket policies | `map(object)` | `{}` | no |
| bucket_lock_configurations | Map of WORM configurations | `map(object)` | `{}` | no |
| objects | Map of objects to upload | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_id | Scaleway Project ID |
| region | Deployment region |
| s3_endpoint | S3 API endpoint URL |
| buckets | Complete bucket details map |
| bucket_names | List of bucket names |
| bucket_ids | Map of bucket keys to IDs |
| bucket_endpoints | Map of bucket S3 endpoints |
| bucket_arns | Map of bucket ARNs |
| website_endpoints | Map of website configurations |
| website_urls | Map of website URLs |
| objects | Map of uploaded objects |
| object_urls | Map of object URLs |
| lock_configurations | Map of lock configurations |
| aws_cli_config | AWS CLI configuration commands |
| environment_variables | Environment variables for S3 tools |
<!-- END_TF_DOCS -->

## Bucket Configuration Reference

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | required | Globally unique bucket name (3-63 chars) |
| `acl` | string | `"private"` | Access control: private, public-read, public-read-write, authenticated-read |
| `force_destroy` | bool | `false` | Allow deletion of non-empty bucket |
| `versioning` | bool | `false` | Enable object versioning |
| `object_lock_enabled` | bool | `false` | Enable WORM (cannot be disabled once enabled) |
| `tags` | list(string) | `[]` | Bucket-specific tags |
| `cors_rules` | list(object) | `[]` | CORS configuration |
| `lifecycle_rules` | list(object) | `[]` | Lifecycle management rules |
| `website` | object | `null` | Static website configuration |

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
