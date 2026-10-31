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

  mock_resource "scaleway_block_volume" {
    defaults = {
      id = "fr-par-1/22222222-2222-2222-2222-222222222222"
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

run "rejects_malformed_snapshot_timeout" {
  command = plan

  variables {
    block_snapshots = {
      bad = {
        volume_key = "db-1"
        timeouts   = { create = "ten minutes" }
      }
    }
  }

  expect_failures = [var.block_snapshots]
}

run "rejects_object_storage_class_outside_provider_list" {
  command = plan

  variables {
    objects = {
      bad = { bucket_key = "data-1", key = "a.txt", content = "x", storage_class = "DEEP_ARCHIVE" }
    }
  }

  expect_failures = [var.objects]
}

run "rejects_object_metadata_with_uppercase_key" {
  command = plan

  variables {
    objects = {
      bad = { bucket_key = "data-1", key = "a.txt", content = "x", metadata = { Owner = "backup" } }
    }
  }

  expect_failures = [var.objects]
}

run "rejects_lifecycle_standard_ia" {
  command = plan

  variables {
    buckets = {
      data = {
        name = "acme-data"
        lifecycle_rules = [{
          id         = "ia"
          transition = [{ days = 30, storage_class = "STANDARD_IA" }]
        }]
      }
    }
  }

  expect_failures = [var.buckets]
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

run "rejects_policy_with_unexpanded_bucket_key" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data" }
    }
    bucket_policies = {
      p = { bucket_key = "data", policy = "{}" } # expanded key is data-1
    }
  }

  expect_failures = [var.bucket_policies]
}

run "rejects_lock_configuration_with_unknown_bucket_key" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock_enabled = true }
    }
    bucket_lock_configurations = {
      legal = {
        bucket_key = "data-2" # count is 1
        rule       = { default_retention = { mode = "GOVERNANCE", days = 30 } }
      }
    }
  }

  expect_failures = [var.bucket_lock_configurations]
}

run "rejects_object_with_unknown_bucket_key" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data" }
    }
    objects = {
      hello = { bucket_key = "missing-1", key = "hello.txt", content = "hi" }
    }
  }

  expect_failures = [var.objects]
}

run "accepts_expanded_bucket_keys" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", count = 2 }
    }
    bucket_policies = {
      p = { bucket_key = "data-2", policy = "{}" }
    }
    objects = {
      hello = { bucket_key = "data-1", key = "hello.txt", content = "hi" }
    }
  }

  assert {
    condition     = length(scaleway_object_bucket_policy.this) == 1 && length(scaleway_object.this) == 1
    error_message = "expanded bucket keys should resolve to the policy and the object"
  }
}

run "rejects_bucket_name_overflowing_with_count_suffix" {
  command = plan

  variables {
    buckets = {
      data = { name = "a23456789012345678901234567890123456789012345678901234567890bc", count = 2 } # 62 chars + "-2"
    }
  }

  expect_failures = [var.buckets]
}

run "accepts_bucket_name_filling_63_chars_with_count_suffix" {
  command = plan

  variables {
    buckets = {
      data = { name = "a2345678901234567890123456789012345678901234567890123456789ab", count = 2 } # 61 chars + "-2"
    }
  }

  assert {
    condition     = length(scaleway_object_bucket.this["data-2"].name) == 63
    error_message = "a 61-character name with a -2 suffix is 63 characters and must be accepted"
  }
}

run "uppercase_export_extension_gets_count_suffix" {
  command = plan

  variables {
    buckets = {
      backups = { name = "acme-backups" }
    }
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = {
        volume_key = "db-1"
        count      = 2
        export     = { bucket = "acme-backups", key = "db.QCOW2" }
      }
    }
  }

  assert {
    condition     = local.expanded_block_snapshots["snap-1"].export.key == "db-1.QCOW2" && local.expanded_block_snapshots["snap-2"].export.key == "db-2.QCOW2"
    error_message = "uppercase extensions must receive the -<n> suffix so exports do not collide"
  }
}

run "lowercase_export_extension_keeps_count_suffix" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = {
        volume_key = "db-1"
        count      = 2
        export     = { bucket = "acme-backups", key = "db.qcow2" }
      }
    }
  }

  assert {
    condition     = local.expanded_block_snapshots["snap-2"].export.key == "db-2.qcow2"
    error_message = "lowercase extension should still receive the -<n> suffix"
  }
}

run "warns_when_prevent_destroy_requested" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000, prevent_destroy = true }
    }
  }

  expect_failures = [check.block_volume_prevent_destroy_not_enforced]
}

run "no_prevent_destroy_warning_by_default" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
  }

  assert {
    condition     = length(scaleway_block_volume.this) == 1
    error_message = "a volume without prevent_destroy plans normally and the check stays silent"
  }
}

run "snapshot_timeouts_reach_both_snapshot_resources" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = {
        volume_key = "db-1"
        count      = 2
        timeouts   = { create = "30m" }
      }
      restored = {
        zone     = "fr-par-1"
        import   = { bucket = "acme-backups", key = "db.qcow2" }
        timeouts = { create = "1h30m", delete = "10m" }
      }
      plain = {
        volume_key = "db-1"
      }
    }
  }

  assert {
    condition     = scaleway_block_snapshot.this["snap-1"].timeouts.create == "30m" && scaleway_block_snapshot.this["snap-2"].timeouts.create == "30m"
    error_message = "timeouts.create should be planned on every snapshot of the entry"
  }

  assert {
    condition     = scaleway_block_snapshot.imported["restored-1"].timeouts.create == "1h30m" && scaleway_block_snapshot.imported["restored-1"].timeouts.delete == "10m"
    error_message = "timeouts should be planned on imported snapshots"
  }

  assert {
    condition     = scaleway_block_snapshot.this["plain-1"].timeouts == null
    error_message = "a snapshot without timeouts should keep the provider defaults"
  }
}

run "object_hash_storage_class_and_metadata_are_planned" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data" }
    }
    objects = {
      archive = {
        bucket_key    = "data-1"
        key           = "a.txt"
        content       = "x"
        hash          = "d41d8cd98f00b204e9800998ecf8427e"
        storage_class = "GLACIER"
        metadata      = { owner = "backup" }
      }
      plain = { bucket_key = "data-1", key = "b.txt", content = "y" }
    }
  }

  assert {
    condition     = scaleway_object.this["archive"].hash == "d41d8cd98f00b204e9800998ecf8427e" && scaleway_object.this["archive"].storage_class == "GLACIER" && scaleway_object.this["archive"].metadata["owner"] == "backup"
    error_message = "hash, storage_class and metadata should be passed to the object"
  }

  assert {
    condition     = scaleway_object.this["plain"].hash == null && scaleway_object.this["plain"].metadata == null
    error_message = "unset hash and metadata should stay null"
  }
}

run "block_outputs_expose_srn" {
  command = apply

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap     = { volume_key = "db-1" }
      restored = { zone = "fr-par-1", import = { bucket = "acme-backups", key = "db.qcow2" } }
    }
  }

  assert {
    condition     = can(output.block_volumes["db-1"].srn) && can(output.block_snapshots["snap-1"].srn) && can(output.block_snapshots["restored-1"].srn)
    error_message = "block_volumes and block_snapshots outputs should expose srn"
  }
}
