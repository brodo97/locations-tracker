output "athena_database_name" {
  description = "Athena database name used for location queries."
  value       = aws_athena_database.locations.name
}

output "athena_table_name" {
  description = "Athena table name that maps partitioned JSONL objects."
  value       = aws_glue_catalog_table.locations.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup configured by this addon."
  value       = aws_athena_workgroup.locations.name
}

output "athena_create_table_sql_example" {
  description = "Equivalent CREATE EXTERNAL TABLE SQL used by this addon."
  value       = <<-SQL
CREATE EXTERNAL TABLE ${aws_glue_catalog_table.locations.name} (
  _type string,
  _id string,
  lat double,
  lon double,
  tst bigint,
  created_at bigint,
  acc double,
  alt double,
  batt int,
  vel double,
  cog double,
  conn string,
  bs int,
  m int,
  source string,
  tid string,
  topic string,
  vac int,
  SSID string,
  BSSID string,
  t string
)
PARTITIONED BY (year string, month string, day string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION '${local.table_root_location}'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.year.type'='integer',
  'projection.month.type'='integer',
  'projection.day.type'='integer',
  'projection.year.range'='${var.projection_year_start},${var.projection_year_end}',
  'projection.month.range'='1,12',
  'projection.day.range'='1,31',
  'projection.month.digits'='2',
  'projection.day.digits'='2',
  'storage.location.template'='${local.table_location_template}'
);
SQL
}

output "athena_query_examples" {
  description = "Ready-to-use Athena SELECT examples against projected partitions."
  value       = <<-SQL
-- Projection eliminates MSCK REPAIR TABLE and keeps metadata operations cheap.
SELECT lat, lon, tst
FROM ${aws_glue_catalog_table.locations.name}
WHERE year = '2026' AND month = '03';

SELECT _type, lat, lon, batt, vel, conn, tst
FROM ${aws_glue_catalog_table.locations.name}
WHERE year = '2026' AND month = '03' AND day = '25'
ORDER BY tst DESC
LIMIT 100;
SQL
}
