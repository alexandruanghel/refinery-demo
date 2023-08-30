import argparse
import os

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql import types as T


def _getSpark(master: str = None, app_name: str = "tableUtils") -> SparkSession:
    """Start and get the Spark session."""
    if not master:
        master = "local"
        if "DATABRICKS_RUNTIME_VERSION" in os.environ:
            master = ""
    if len(master) > 0:
        from delta import configure_spark_with_delta_pip

        builder = (
            SparkSession.builder.master(master)
            .appName(app_name)
            .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
            .config(
                "spark.sql.catalog.spark_catalog",
                "org.apache.spark.sql.delta.catalog.DeltaCatalog",
            )
        )
        spark = configure_spark_with_delta_pip(builder).getOrCreate()
    else:
        spark = SparkSession.builder.appName(app_name).getOrCreate()

    return spark


def wait_for_stream(spark: SparkSession, name: str):
    import time
    queries = list(filter(lambda query: query.name == name, spark.streams.active))

    while len(queries) > 0 and len(queries[0].recentProgress) < 2:
        time.sleep(5)
        queries = list(filter(lambda query: query.name == name, spark.streams.active))


def fix_columns(col: str) -> str:
    replacements = {" ": "_", "(": "", ")": ""}
    #replacements = {" ": "", "(": "_", ")": ""}
    return "".join([replacements.get(c, c) for c in col])


def stream_csv_to_delta(spark: SparkSession, csv_path: str, target_table: str, target_path: str, checkpoint_path: str, delimiter: str = ",", schema: T.StructType() = None, max_files_per_trigger: int = 1) -> None:
    if not schema:
        df = (spark
              .read
              .format("csv")
              .option("inferSchema", True)
              .option("header", True)
              .option("delimiter", delimiter)
              .option("multiLine", "true")
              .load(csv_path)
              )
        fixed_columns = map(fix_columns, df.columns)
        schema = df.toDF(*fixed_columns).schema

    stream_df = (spark
          .readStream
          .format("csv")
          .option("header", True)
          .option("delimiter", delimiter)
          .option("multiLine", "true")
          .schema(schema)
          .option("maxFilesPerTrigger", max_files_per_trigger)
          .load(csv_path)
          )

    stream_df = stream_df.withColumn("ingestion_date", F.current_timestamp().cast("date"))

    query_name = f"CsvToDelta-{target_table}"
    spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", True)

    (stream_df.writeStream
     .format("delta")
     .outputMode("append")
     .option("checkpointLocation", checkpoint_path)
     .queryName(query_name)
     .trigger(once=True)
     #  .trigger(processingTime="2 minutes")                            # Configure for a 2-minutes micro-batch
     .start(target_path)
     )

    wait_for_stream(spark, query_name)

    spark.sql(f"CREATE TABLE IF NOT EXISTS {target_table} "
              "USING DELTA "
              f"LOCATION '{target_path}'")
  

def landing_to_bronze(spark: SparkSession, source_base_path: str, pipeline_base_path: str, pipeline_db: str) -> None:
    #
    # Set paths and tables
    #
    landing_fraud = f"{source_base_path.rstrip('/')}/fraud_report"

    bronze_tables_base_path = f"{pipeline_base_path.rstrip('/')}/bronze"
    bronze_fraud_path = f"{bronze_tables_base_path}/fraud_report.delta"
    bronze_fraud_checkpoint = f"{bronze_tables_base_path}/fraud_report.checkpoint"

    bronze_fraud_table = f"{pipeline_db}.bronze_fraud_reports"

    spark.sql(f"CREATE DATABASE IF NOT EXISTS {pipeline_db}")

    #
    # Checks
    #
    print(landing_fraud)
    spark.sql(f"SELECT * FROM csv.`{landing_fraud}` LIMIT 5").show()

    #
    # Landing to Bronze stream
    #
    # read the data stream and add the partition column
    stream_csv_to_delta(spark, landing_fraud, bronze_fraud_table, bronze_fraud_path, bronze_fraud_checkpoint, delimiter=",")

    #
    # Show results
    #
    spark.sql(f"SELECT * FROM {bronze_fraud_table}").limit(5).show()


def get_args():
    parser = argparse.ArgumentParser(description='Parameters')
    parser.add_argument('--sparkMaster', required=False, default="", help="Spark Master")
    parser.add_argument('--sourceBasePath', required=True, help="Data sources base path")
    parser.add_argument('--pipelineBasePath', required=True, help="Pipeline base path")
    parser.add_argument('--pipelineDatabase', required=True, help="Pipeline database name")
    return parser


def main() -> None:
    """Main definition.
    :return: None
    """

    #
    # Get command line arguments
    #
    # get command line arguments
    args = get_args().parse_args()
    source_base_path = args.sourceBasePath
    pipeline_base_path = args.pipelineBasePath
    pipeline_db = args.pipelineDatabase

    #
    # Initialize the Spark application
    #
    spark = _getSpark(app_name="Landing_to_Bronze")

    #
    # Execute
    #
    landing_to_bronze(spark, source_base_path, pipeline_base_path, pipeline_db)


if __name__ == '__main__':
    main()
