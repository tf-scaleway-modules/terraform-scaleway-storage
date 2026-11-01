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
  mock_resource "scaleway_block_volume" {
    defaults = {
      id = "fr-par-1/22222222-2222-2222-2222-222222222222"
    }
  }

  mock_resource "scaleway_object_bucket" {
    defaults = {
      endpoint     = "https://acme.s3.fr-par.scw.cloud"
      api_endpoint = "https://s3.fr-par.scw.cloud"
    }
  }

  mock_resource "scaleway_object_bucket_website_configuration" {
    defaults = {
      website_endpoint = "acme.s3-website.fr-par.scw.cloud"
    }
  }
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

run "explicit_project_region_and_zone_reach_resources" {
  command = plan

  variables {
    project_id = "11111111-1111-1111-1111-111111111111"
    region     = "nl-ams"
    zone       = "nl-ams-1"
    buckets = {
      data = { name = "acme-data", acl = "public-read", server_side_encryption = {}, website = { index_document = "index.html" } }
    }
    objects = {
      hello = { bucket_key = "data-1", key = "hello.txt", content = "hi" }
    }
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      restored = { import = { bucket = "acme-backups", key = "db.qcow2" } }
    }
  }

  assert {
    condition = alltrue([
      scaleway_object_bucket.this["data-1"].project_id == var.project_id,
      scaleway_object_bucket_acl.this["data-1"].project_id == var.project_id,
      scaleway_object_bucket_server_side_encryption_configuration.this["data-1"].project_id == var.project_id,
      scaleway_object_bucket_website_configuration.this["data-1"].project_id == var.project_id,
      scaleway_object.this["hello"].project_id == var.project_id,
      scaleway_block_volume.this["db-1"].project_id == var.project_id,
      scaleway_block_snapshot.imported["restored-1"].project_id == var.project_id,
    ])
    error_message = "project_id should reach every resource"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].region == "nl-ams" && scaleway_object.this["hello"].region == "nl-ams"
    error_message = "region should reach the Object Storage resources"
  }

  assert {
    condition     = scaleway_block_volume.this["db-1"].zone == "nl-ams-1" && scaleway_block_snapshot.imported["restored-1"].zone == "nl-ams-1"
    error_message = "zone should be the default of volumes and imported snapshots"
  }
}

run "absent_project_region_and_zone_stay_unset" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data" }
    }
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      restored = { import = { bucket = "acme-backups", key = "db.qcow2" } }
    }
  }

  assert {
    condition     = var.project_id == null && var.region == null && var.zone == null
    error_message = "project_id, region and zone should default to null"
  }

  assert {
    condition     = local.expanded_block_volumes["db-1"].zone == null && local.expanded_block_snapshots["restored-1"].zone == null
    error_message = "an unset zone should send no module zone to the provider"
  }
}

run "per_volume_zone_beats_module_zone" {
  command = plan

  variables {
    zone = "fr-par-1"
    block_volumes = {
      db  = { size_in_gb = 10, iops = 5000, zone = "fr-par-2" }
      app = { size_in_gb = 10, iops = 5000 }
    }
  }

  assert {
    condition     = scaleway_block_volume.this["db-1"].zone == "fr-par-2" && scaleway_block_volume.this["app-1"].zone == "fr-par-1"
    error_message = "a volume zone should win over var.zone, which applies to the others"
  }
}

run "global_tags_reach_every_taggable_resource" {
  command = plan

  variables {
    tags = { env = "prod" }
    buckets = {
      data = { name = "acme-data", tags = { env = "dev", team = "a" } }
    }
    objects = {
      hello = { bucket_key = "data-1", key = "hello.txt", content = "hi", tags = { kind = "page" } }
    }
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000, tags = ["db", "env:prod"] }
    }
    block_snapshots = {
      snap = { volume_key = "db-1", tags = ["backup"] }
    }
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].tags == tomap({ env = "dev", team = "a" })
    error_message = "bucket tags should win over global tags on a shared key"
  }

  assert {
    condition     = scaleway_object.this["hello"].tags == tomap({ env = "prod", kind = "page" })
    error_message = "the object should carry the global tags merged with its own"
  }

  assert {
    condition     = scaleway_block_volume.this["db-1"].tags == tolist(["db", "env:prod"])
    error_message = "the volume should carry db and env:prod exactly once"
  }

  assert {
    condition     = scaleway_block_snapshot.this["snap-1"].tags == tolist(["backup", "env:prod"])
    error_message = "the snapshot should carry its tag then the global tag as key:value"
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

run "rejects_invalid_project_id" {
  command = plan

  variables {
    project_id = "my-project"
  }

  expect_failures = [var.project_id]
}

run "rejects_invalid_zone" {
  command = plan

  variables {
    zone = "paris"
  }

  expect_failures = [var.zone]
}

run "rejects_malformed_volume_zone" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000, zone = "paris" }
    }
  }

  expect_failures = [var.block_volumes]
}

run "rejects_volume_without_size_or_snapshot" {
  command = plan

  variables {
    block_volumes = {
      db = { iops = 5000 }
    }
  }

  expect_failures = [var.block_volumes]
}

run "accepts_volume_restored_without_size" {
  command = plan

  variables {
    block_volumes = {
      db = { iops = 5000, snapshot_id = "fr-par-1/33333333-3333-3333-3333-333333333333" }
    }
  }

  assert {
    condition     = length(scaleway_block_volume.this) == 1 && scaleway_block_volume.this["db-1"].snapshot_id != null
    error_message = "a volume restored from a snapshot needs no size_in_gb"
  }
}

run "rejects_snapshot_with_unknown_volume_key" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = { volume_key = "db" } # expanded key is db-1
    }
  }

  expect_failures = [var.block_snapshots]
}

run "rejects_snapshot_with_out_of_range_volume_key" {
  command = plan

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = { volume_key = "db-2" } # count is 1
    }
  }

  expect_failures = [var.block_snapshots]
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
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "INVALID", days = 30 } } }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_retention_with_both_units" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "GOVERNANCE", days = 30, years = 1 } } }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_retention_with_no_unit" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "GOVERNANCE" } } }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_retention_days_out_of_range" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "GOVERNANCE", days = 36501 } } }
    }
  }

  expect_failures = [var.buckets]
}

run "rejects_retention_years_out_of_range" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "COMPLIANCE", years = 0 } } }
    }
  }

  expect_failures = [var.buckets]
}

run "object_lock_without_retention_forces_versioning" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = {} }
      open = { name = "acme-open" }
    }
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].object_lock_enabled && scaleway_object_bucket.this["data-1"].versioning[0].enabled
    error_message = "object_lock = {} should enable object lock and versioning"
  }

  assert {
    condition     = length(scaleway_object_bucket_lock_configuration.this) == 0
    error_message = "no default retention should be planned without default_retention"
  }

  assert {
    condition     = !scaleway_object_bucket.this["open-1"].object_lock_enabled && !scaleway_object_bucket.this["open-1"].versioning[0].enabled
    error_message = "a bucket without object_lock should have neither lock nor versioning"
  }
}

run "governance_retention_in_days_is_planned" {
  command = plan

  variables {
    buckets = {
      data = { name = "acme-data", object_lock = { default_retention = { mode = "GOVERNANCE", days = 30 } } }
      logs = { name = "acme-logs" }
    }
  }

  assert {
    condition     = keys(scaleway_object_bucket_lock_configuration.this) == ["data-1"]
    error_message = "the lock configuration should be keyed by the expanded bucket key and only exist for locked buckets"
  }

  assert {
    condition     = scaleway_object_bucket_lock_configuration.this["data-1"].rule[0].default_retention[0].mode == "GOVERNANCE" && scaleway_object_bucket_lock_configuration.this["data-1"].rule[0].default_retention[0].days == 30
    error_message = "the retention mode and days should be passed to the lock configuration"
  }
}

run "lifecycle_tag_filter_is_sent_only_when_set" {
  command = plan

  variables {
    buckets = {
      data = {
        name = "acme-data"
        lifecycle_rules = [
          { id = "temp", tags = { tier = "temp" }, expiration = { days = 7 } },
          { id = "all", expiration = { days = 30 } },
        ]
      }
    }
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].lifecycle_rule[0].tags == tomap({ tier = "temp" })
    error_message = "the tag filter should be passed to the rule"
  }

  assert {
    condition     = scaleway_object_bucket.this["data-1"].lifecycle_rule[1].tags == null
    error_message = "a rule without tags should send no tag filter"
  }
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

run "snapshot_export_output_reports_the_suffixed_key" {
  command = apply

  variables {
    block_volumes = {
      db = { size_in_gb = 10, iops = 5000 }
    }
    block_snapshots = {
      snap = { volume_key = "db-1", count = 2, export = { bucket = "acme-backups", key = "db.qcow2" } }
    }
  }

  assert {
    condition     = output.block_snapshots["snap-2"].export == { bucket = "acme-backups", key = "db-2.qcow2" }
    error_message = "block_snapshots should report the effective export bucket and key"
  }
}

run "bucket_and_object_outputs_report_provider_endpoints" {
  command = apply

  variables {
    buckets = {
      site = { name = "acme-site", website = { index_document = "index.html" } }
      data = { name = "acme-data" }
    }
    objects = {
      hello = { bucket_key = "data-1", key = "hello.txt", content = "hi" }
    }
  }

  assert {
    condition     = output.buckets["data-1"].endpoint == "https://acme.s3.fr-par.scw.cloud" && output.buckets["data-1"].api_endpoint == "https://s3.fr-par.scw.cloud"
    error_message = "buckets should report the endpoints the provider returns"
  }

  assert {
    condition     = output.buckets["data-1"].website_endpoint == null && output.buckets["site-1"].website_endpoint == "acme.s3-website.fr-par.scw.cloud"
    error_message = "website_endpoint should be null without a website and the provider value with one"
  }

  assert {
    condition     = output.objects["hello"].url == "https://acme.s3.fr-par.scw.cloud/hello.txt"
    error_message = "the object url should be the bucket endpoint followed by the key"
  }

  assert {
    condition     = can(output.buckets["data-1"].region) && can(output.buckets["data-1"].versioning_enabled) && can(output.buckets["data-1"].object_lock_enabled)
    error_message = "buckets should report region, versioning_enabled and object_lock_enabled"
  }
}

run "no_resources_yield_empty_outputs" {
  command = apply

  assert {
    condition     = length(output.buckets) == 0 && length(output.objects) == 0 && length(output.block_volumes) == 0 && length(output.block_snapshots) == 0
    error_message = "every output should be an empty map without configuration"
  }
}
