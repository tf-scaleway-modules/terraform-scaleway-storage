# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                  EXAMPLE-PARITY TESTS                                         ║
# ║                                                                              ║
# ║  Asserts that every reference in examples/ resolves to an actual resource    ║
# ║  expanded by the module. Mirrors the example module calls 1:1.               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

mock_provider "scaleway" {
  mock_data "scaleway_account_project" {
    defaults = { id = "11111111-1111-1111-1111-111111111111" }
  }
  # The Scaleway provider client-side validates that volume_id is a UUID.
  # Mocks return random strings by default, so pin id/zone to plausible values.
  mock_resource "scaleway_block_volume" {
    defaults = {
      id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

variables {
  organization_id = "11111111-1111-1111-1111-111111111111"
  project_name    = "test-project"
}

# ─── examples/minimal — single private bucket ──────────────────────────────────

run "minimal_example_creates_single_bucket" {
  command = plan

  variables {
    buckets = {
      data = { name = "example-data-bucket" }
    }
  }

  assert {
    condition     = length(scaleway_object_bucket.this) == 1
    error_message = "minimal example should create exactly 1 bucket"
  }

  assert {
    condition     = contains(keys(scaleway_object_bucket.this), "data-1")
    error_message = "minimal example references buckets[\"data-1\"] in outputs.tf — must exist"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].name == "example-data-bucket"
    error_message = "count=1 should not append a suffix to the bucket name"
  }
}

# ─── examples/complete — full configuration mirroring main.tf ──────────────────

run "complete_example_resource_topology" {
  command = plan

  variables {
    region = "fr-par"
    tags = {
      environment = "dev"
      managed-by  = "terraform"
      example     = "complete"
    }

    buckets = {
      data = {
        count         = 10
        name          = "example-data-dev"
        acl           = "private"
        versioning    = true
        force_destroy = true
        lifecycle_rules = [{
          id                                = "cleanup-multipart"
          enabled                           = true
          abort_incomplete_multipart_upload = { days_after_initiation = 7 }
        }]
        tags = { type = "data" }
      }
      assets = {
        name          = "example-assets-dev"
        acl           = "public-read"
        force_destroy = true
        cors_rules = [{
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
          allowed_headers = ["*"]
          max_age_seconds = 3600
        }]
        tags = { type = "assets" }
      }
      logs = {
        name          = "example-logs-dev"
        acl           = "private"
        versioning    = true
        force_destroy = true
        lifecycle_rules = [{
          id         = "archive-and-expire"
          enabled    = true
          prefix     = "app/"
          transition = [{ days = 30, storage_class = "GLACIER" }]
          expiration = { days = 365 }
        }]
        tags = { type = "logs", retention = "1year" }
      }
      website = {
        name          = "example-website-dev"
        acl           = "public-read"
        force_destroy = true
        website       = { index_document = "index.html", error_document = "404.html" }
        cors_rules = [{
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
          allowed_headers = ["*"]
          max_age_seconds = 86400
        }]
        tags = { type = "website" }
      }
    }

    objects = {
      website_index = {
        bucket_key   = "website-1"
        key          = "index.html"
        content      = "<html></html>"
        content_type = "text/html"
        visibility   = "public-read"
      }
      website_404 = {
        bucket_key   = "website-1"
        key          = "404.html"
        content      = "<html></html>"
        content_type = "text/html"
        visibility   = "public-read"
      }
      robots = {
        bucket_key   = "website-1"
        key          = "robots.txt"
        content      = "User-agent: *\nAllow: /"
        content_type = "text/plain"
        visibility   = "public-read"
      }
    }

    block_volumes = {
      database = {
        name       = "example-db-dev"
        size_in_gb = 100
        iops       = 15000
        zone       = "fr-par-1"
        tags       = ["database", "dev"]
      }
      app = {
        name       = "example-app-dev"
        count      = 2
        size_in_gb = 50
        iops       = 5000
        zone       = "fr-par-1"
        tags       = ["application", "dev"]
      }
      logs = {
        name       = "example-logs-vol-dev"
        size_in_gb = 20
        iops       = 5000
        zone       = "fr-par-1"
        tags       = ["logs", "dev"]
      }
    }

    block_snapshots = {
      database_backup = {
        name       = "example-db-backup-dev"
        volume_key = "database-1"
        tags       = ["backup", "database", "dev"]
        export = {
          bucket = "example-data-dev-1"
          key    = "snapshots/database-backup.qcow2"
        }
      }
      app_backup = {
        count      = 2
        volume_key = "app-1"
        tags       = ["backup", "app", "dev"]
        export = {
          bucket = "example-data-dev-1"
          key    = "snapshots/app-backup.qcow2"
        }
      }
    }
  }

  # ─── bucket count + named expanded keys ─────────────────────────────────────
  assert {
    condition     = length(scaleway_object_bucket.this) == 13 # 10 data + 1 assets + 1 logs + 1 website
    error_message = "complete example should plan 13 buckets total (10 data + 1 assets + 1 logs + 1 website)"
  }

  assert {
    condition = alltrue([
      contains(keys(scaleway_object_bucket.this), "data-1"),
      contains(keys(scaleway_object_bucket.this), "data-10"),
      contains(keys(scaleway_object_bucket.this), "assets-1"),
      contains(keys(scaleway_object_bucket.this), "logs-1"),
      contains(keys(scaleway_object_bucket.this), "website-1"),
    ])
    error_message = "all bucket keys referenced by examples/complete/outputs.tf must exist"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-10"].name == "example-data-dev-10"
    error_message = "data bucket count=10 must produce -1 ... -10 name suffixes"
  }

  # ─── ACL is only created for non-private buckets ───────────────────────────
  assert {
    condition     = length(scaleway_object_bucket_acl.this) == 2 # assets + website
    error_message = "ACL resources should only be created for non-private buckets (assets, website)"
  }

  # ─── website config exists for the website bucket ──────────────────────────
  assert {
    condition     = length(scaleway_object_bucket_website_configuration.this) == 1
    error_message = "website config should be created for exactly 1 bucket"
  }

  assert {
    condition     = contains(keys(scaleway_object_bucket_website_configuration.this), "website-1")
    error_message = "website config must be keyed website-1 (matches website_urls[\"website-1\"] in outputs)"
  }

  # ─── objects reference an existing bucket_key ──────────────────────────────
  assert {
    condition     = length(scaleway_object.this) == 3
    error_message = "complete example should plan 3 uploaded objects"
  }

  # ─── block volumes ──────────────────────────────────────────────────────────
  assert {
    condition     = length(scaleway_block_volume.this) == 4 # database-1 + app-1 + app-2 + logs-1
    error_message = "complete example should plan 4 block volumes (1 database + 2 app + 1 logs)"
  }

  assert {
    condition = alltrue([
      contains(keys(scaleway_block_volume.this), "database-1"),
      contains(keys(scaleway_block_volume.this), "app-1"),
      contains(keys(scaleway_block_volume.this), "app-2"),
      contains(keys(scaleway_block_volume.this), "logs-1"),
    ])
    error_message = "all volume keys referenced by examples/complete/outputs.tf must exist"
  }

  # ─── block snapshots — count=2 on app_backup expands to 2 snapshots ─────────
  assert {
    condition     = length(scaleway_block_snapshot.this) == 3 # database_backup-1 + app_backup-1 + app_backup-2
    error_message = "complete example should plan 3 block snapshots"
  }
}
