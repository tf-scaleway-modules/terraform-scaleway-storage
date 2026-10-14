# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         MODULE TESTS — VALIDATIONS                           ║
# ║                                                                              ║
# ║  Hermetic tests that use mock_provider so no Scaleway credentials are        ║
# ║  required. Runs the validation blocks declared in variables.tf and the       ║
# ║  count-expansion logic in locals.tf.                                         ║
# ║                                                                              ║
# ║  Run:  terraform test                                                        ║
# ║  Or:   terraform test -filter=tests/main.tftest.hcl                          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

mock_provider "scaleway" {
  mock_data "scaleway_account_project" {
    defaults = {
      id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

variables {
  organization_id = "11111111-1111-1111-1111-111111111111"
  project_name    = "test-project"
}

# ─── happy path: count expansion produces expanded keys ────────────────────────

run "expands_buckets_by_count" {
  command = plan

  variables {
    buckets = {
      data = {
        name  = "acme-data"
        count = 3
      }
    }
  }

  assert {
    condition     = length(local.expanded_buckets) == 3
    error_message = "count=3 should produce 3 expanded buckets"
  }

  assert {
    condition     = contains(keys(local.expanded_buckets), "data-1")
    error_message = "expanded keys should include data-1"
  }

  assert {
    condition     = local.expanded_buckets["data-2"].name == "acme-data-2"
    error_message = "name should be suffixed with -2 when count > 1"
  }
}

run "count_10_creates_10_actual_bucket_resources" {
  command = plan

  variables {
    buckets = {
      data = {
        name  = "acme-data"
        count = 10
      }
    }
  }

  assert {
    condition     = length(local.expanded_buckets) == 10
    error_message = "count=10 should produce 10 entries in local.expanded_buckets"
  }

  assert {
    condition     = length(scaleway_object_bucket.this) == 10
    error_message = "count=10 should produce 10 actual scaleway_object_bucket resources"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-10"].name == "acme-data-10"
    error_message = "10th bucket should exist with -10 suffix"
  }
}

run "single_bucket_keeps_original_name" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data" }
    }
  }

  assert {
    condition     = local.expanded_buckets["data-1"].name == "acme-data"
    error_message = "count=1 should not append a suffix to the name"
  }
}

run "s3_endpoint_matches_region" {
  command = plan

  variables {
    region = "nl-ams"
  }

  assert {
    condition     = local.s3_endpoint == "https://s3.nl-ams.scw.cloud"
    error_message = "s3_endpoint should be derived from var.region"
  }
}

run "sse_and_noncurrent_lifecycle" {
  command = plan

  variables {
    buckets = {
      data = {
        name                   = "acme-data"
        versioning             = true
        server_side_encryption = {}
        lifecycle_rules = [{
          id                            = "noncurrent"
          expiration                    = { expired_object_delete_marker = true }
          noncurrent_version_expiration = { noncurrent_days = 90 }
          noncurrent_version_transition = [{ noncurrent_days = 30, storage_class = "GLACIER" }]
        }]
      }
      logs = {
        name = "acme-logs"
      }
    }
  }

  assert {
    condition     = keys(scaleway_object_bucket_server_side_encryption_configuration.this) == ["data-1"]
    error_message = "SSE configuration should only be created for buckets that set server_side_encryption"
  }

  assert {
    condition     = one(one(scaleway_object_bucket_server_side_encryption_configuration.this["data-1"].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "sse_algorithm should default to AES256"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].lifecycle_rule[0].noncurrent_version_expiration[0].noncurrent_days == 90
    error_message = "noncurrent_version_expiration should be passed to the bucket"
  }
}

# ─── validation: rejects invalid inputs ────────────────────────────────────────

run "rejects_invalid_organization_id" {
  command = plan

  variables {
    organization_id = "not-a-uuid"
  }

  expect_failures = [var.organization_id]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    region = "us-east-1"
  }

  expect_failures = [var.region]
}

run "rejects_public_read_write_acl" {
  command = plan

  variables {
    buckets = {
      data = {
        name = "acme-data"
        acl  = "public-read-write"
      }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    buckets = {
      data = { name = "AcmeData" } # uppercase rejected
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_invalid_iops" {
  command = plan

  variables {
    block_volumes = {
      db = {
        size_in_gb = 10
        iops       = 7000 # only 5000 or 15000 allowed
      }
    }
  }

  expect_failures = [var.block_volumes]
}

run "rejects_undersized_volume" {
  command = plan

  variables {
    block_volumes = {
      db = {
        size_in_gb = 1 # minimum is 5
        iops       = 5000
      }
    }
  }

  expect_failures = [var.block_volumes]
}

run "rejects_invalid_lock_mode" {
  command = plan

  variables {
    bucket_lock_configurations = {
      legal = {
        bucket_key = "data"
        rule = {
          default_retention = {
            mode = "INVALID"
            days = 30
          }
        }
      }
    }
  }

  expect_failures = [var.bucket_lock_configurations]
}

run "rejects_object_with_both_source_and_content" {
  command = plan

  variables {
    objects = {
      both = {
        bucket_key = "data"
        key        = "file.txt"
        source     = "/tmp/file.txt"
        content    = "inline"
      }
    }
  }

  expect_failures = [var.objects]
}

run "rejects_snapshot_export_without_qcow_extension" {
  command = plan

  variables {
    block_snapshots = {
      bad = {
        volume_key = "db-1"
        export = {
          bucket = "backups"
          key    = "snapshot.bin"
        }
      }
    }
  }

  expect_failures = [var.block_snapshots]
}

run "rejects_kms_sse_without_key" {
  command = plan

  variables {
    buckets = {
      data = {
        name                   = "acme-data"
        server_side_encryption = { sse_algorithm = "aws:kms" }
      }
    }
  }

  expect_failures = [var.buckets]
}
