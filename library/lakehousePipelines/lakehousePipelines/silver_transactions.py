import argparse
import os

from delta.exceptions import ProtocolChangedException
from pyspark.sql import SparkSession, DataFrame
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


def init_delta_table(spark: SparkSession, table_name: str, schema: T.StructType, path: str, partition_columns: list = None) -> None:
    df = (spark
          .createDataFrame(spark.sparkContext.parallelize([]), schema)
          .limit(0))
    writer = (df
              .write
              .format("delta")
              .mode("ignore")
              )

    if partition_columns is not None:
        writer = writer.partitionBy(*partition_columns)
    try:
        writer.save(path)
        spark.sql(f"CREATE TABLE IF NOT EXISTS {table_name} "
                  "USING DELTA "
                  f"LOCATION '{path}'")
    except ProtocolChangedException as e:
        import time
        time.sleep(30)  # sleep 30s
        writer.save(path)  # retry


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


def clean_bronze_df(bronze_df: DataFrame) -> DataFrame:
    # Drop bad data
    df = bronze_df.drop("ingestion_date")
    for column in df.columns:
        df = df.filter(~F.col(column).startswith("#"))

    # Drop if no country
    if "country" in df.columns:
        df = (df
              .filter(F.col("country").isNotNull())
              )

    # Convert to timestamp
    for column in df.columns:
        if "date" in column:
            df = df.withColumn(column, F.to_timestamp(column, 'MM-dd-yyyy HH:mm:ss'))

    # Add an id
    if "id" not in df.columns:
        df = df.withColumn("id", F.col("numeric_code"))

    # Fill nulls
    df = df.na.fill(0)

    # Drop duplicates
    df = df.dropDuplicates()

    return df


def join_delta_streams(spark: SparkSession, source_table_transactions: str,  source_table_reports: str, target_table: str, target_path: str, checkpoint_path: str, max_files_per_trigger: int = 1) -> None:

    stream_df = (spark
                 .readStream
                 .format("delta")
                 .option("maxFilesPerTrigger", max_files_per_trigger)
                 .table(source_table_transactions)
                 )
    stream_df = clean_bronze_df(stream_df)

    reports_df = (spark
                  .read
                  .format("delta")
                  .table(source_table_reports)
                  )
    reports_df = clean_bronze_df(reports_df)

    # Join the two tables
    joined_df = (stream_df
                 .join(reports_df, on="id", how="left")
                 .withColumn("diffOrig", F.col("newBalanceOrig") - F.col("oldBalanceOrig"))
                 .withColumn("diffDest", F.col("newBalanceDest") - F.col("oldBalanceDest"))
                 )

    query_name = f"DeltaJoin-{target_table}"

    # Create an empty Delta Silver table if one doesn't exist
    if not spark.catalog.tableExists(target_table):
        init_delta_table(spark=spark, table_name=target_table, schema=joined_df.schema, path=target_path)



    (joined_df.writeStream
     .format("delta")
     .outputMode("append")
     .option("checkpointLocation", checkpoint_path)
     .queryName(query_name)
     .trigger(once=True)
     #.trigger(processingTime="1 minute")
     .toTable(target_table)
     )

    wait_for_stream(spark, query_name)


def bronze_to_silver(spark: SparkSession, pipeline_base_path: str, pipeline_db: str) -> None:
    #
    # Set paths and tables
    #
    bronze_fraud_table = f"{pipeline_db}.bronze_fraud_reports"
    bronze_transactions_table = f"{pipeline_db}.bronze_transactions"

    silver_tables_base_path = f"{pipeline_base_path.rstrip('/')}/silver"
    silver_customers_path = f"{silver_tables_base_path}/transactions.delta"
    silver_customers_checkpoint = f"{silver_tables_base_path}/transactions.checkpoint"

    silver_transactions_table = f"{pipeline_db}.silver_transactions"


    spark.sql(f"CREATE DATABASE IF NOT EXISTS {pipeline_db}")

    #
    # Checks
    #
    spark.sql(f"SELECT * FROM {bronze_transactions_table} LIMIT 5").show()

    #
    # Landing to Bronze stream
    #
    # read the data stream and add the partition column

    join_delta_streams(spark,
                       source_table_transactions=bronze_transactions_table,
                       source_table_reports=bronze_fraud_table,
                       target_table=silver_transactions_table,
                       target_path=silver_customers_path,
                       checkpoint_path=silver_customers_checkpoint
                       )

    #
    # Show results
    #
    spark.sql(f"SELECT * FROM {silver_transactions_table}").limit(5).show()


def get_args():
    parser = argparse.ArgumentParser(description='Parameters')
    parser.add_argument('--sparkMaster', required=False, default="", help="Spark Master")
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
    pipeline_base_path = args.pipelineBasePath
    pipeline_db = args.pipelineDatabase

    #
    # Initialize the Spark application
    #
    spark = _getSpark(app_name="Bronze_to_Silver")

    #
    # Execute
    #
    bronze_to_silver(spark, pipeline_base_path, pipeline_db)




if __name__ == '__main__':
    main()
