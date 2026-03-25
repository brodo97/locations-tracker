resource "aws_athena_database" "locations" {
  name   = local.athena_database_name
  bucket = local.data_lake_bucket

  force_destroy = false
}

resource "aws_athena_workgroup" "locations" {
  name = var.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = local.athena_results_location
    }
  }

  tags = local.all_tags
}

resource "aws_glue_catalog_table" "locations" {
  name          = var.athena_table_name
  database_name = aws_athena_database.locations.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    # Partition projection avoids catalog partition management (no MSCK REPAIR).
    "EXTERNAL"               = "TRUE"
    "classification"         = "json"
    "projection.enabled"     = "true"
    "projection.year.type"   = "integer"
    "projection.year.range"  = "${var.projection_year_start},${var.projection_year_end}"
    "projection.month.type"  = "integer"
    "projection.month.range" = "1,12"
    # Month/day folders are zero-padded in S3 (month=03/day=09).
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "storage.location.template" = local.table_location_template
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }

  storage_descriptor {
    location      = local.table_root_location
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "_type"
      type = "string"
    }

    columns {
      name = "_id"
      type = "string"
    }

    columns {
      name = "lat"
      type = "double"
    }

    columns {
      name = "lon"
      type = "double"
    }

    columns {
      name = "tst"
      type = "bigint"
    }

    columns {
      name = "created_at"
      type = "bigint"
    }

    columns {
      name = "acc"
      type = "double"
    }

    columns {
      name = "alt"
      type = "double"
    }

    columns {
      name = "batt"
      type = "int"
    }

    columns {
      name = "vel"
      type = "double"
    }

    columns {
      name = "cog"
      type = "double"
    }

    columns {
      name = "conn"
      type = "string"
    }

    columns {
      name = "bs"
      type = "int"
    }

    columns {
      name = "m"
      type = "int"
    }

    columns {
      name = "source"
      type = "string"
    }

    columns {
      name = "tid"
      type = "string"
    }

    columns {
      name = "topic"
      type = "string"
    }

    columns {
      name = "vac"
      type = "int"
    }

    columns {
      name = "SSID"
      type = "string"
    }

    columns {
      name = "BSSID"
      type = "string"
    }

    columns {
      name = "t"
      type = "string"
    }
  }
}
