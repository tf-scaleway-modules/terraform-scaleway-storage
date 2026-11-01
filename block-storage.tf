# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         SCALEWAY BLOCK STORAGE                               ║
# ║                                                                              ║
# ║  Network-attached SSD volumes (5000/15000 IOPS) and point-in-time            ║
# ║  snapshots, with QCOW2 export/import to/from Object Storage.                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Block Storage Volumes
# ------------------------------------------------------------------------------
# IOPS cannot be changed after creation. Volume must share a zone with the
# Instance to attach.
# ==============================================================================

resource "scaleway_block_volume" "this" {
  for_each = local.expanded_block_volumes

  name        = each.value.name
  iops        = each.value.iops
  size_in_gb  = each.value.size_in_gb
  zone        = each.value.zone
  project_id  = var.project_id
  snapshot_id = each.value.snapshot_id
  tags        = each.value.tags
}

# ==============================================================================
# Block Storage Snapshots — From Volume
# ------------------------------------------------------------------------------
# Created when volume_key is provided. Optionally exports a QCOW2 to Object
# Storage for offsite backup.
# ==============================================================================

resource "scaleway_block_snapshot" "this" {
  for_each = {
    for k, v in local.expanded_block_snapshots : k => v
    if v.volume_key != null
  }

  name       = each.value.name
  volume_id  = scaleway_block_volume.this[each.value.volume_key].id
  zone       = each.value.zone != null ? each.value.zone : scaleway_block_volume.this[each.value.volume_key].zone
  project_id = var.project_id
  tags       = each.value.tags
  timeouts   = each.value.timeouts

  dynamic "export" {
    for_each = each.value.export != null ? [each.value.export] : []
    content {
      bucket = export.value.bucket
      key    = export.value.key
    }
  }
}

# ==============================================================================
# Block Storage Snapshots — Imported From Object Storage
# ------------------------------------------------------------------------------
# Created when import block is provided (and volume_key is null).
# ==============================================================================

resource "scaleway_block_snapshot" "imported" {
  for_each = {
    for k, v in local.expanded_block_snapshots : k => v
    if v.volume_key == null && v.import != null
  }

  name       = each.value.name
  zone       = each.value.zone != null ? each.value.zone : var.zone
  project_id = var.project_id
  tags       = each.value.tags
  timeouts   = each.value.timeouts

  import {
    bucket = each.value.import.bucket
    key    = each.value.import.key
  }

  dynamic "export" {
    for_each = each.value.export != null ? [each.value.export] : []
    content {
      bucket = export.value.bucket
      key    = export.value.key
    }
  }

  depends_on = [scaleway_object_bucket.this]
}
