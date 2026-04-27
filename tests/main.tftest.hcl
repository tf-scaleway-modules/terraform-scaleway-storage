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
