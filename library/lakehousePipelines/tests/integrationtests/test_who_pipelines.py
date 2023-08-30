import os
import pytest

from lakehouseLibs import utils
from lakehousePipelines.run_who_bronze import who_landing_to_bronze, set_paths as set_bronze_paths
from lakehousePipelines.run_who_silver import who_bronze_to_silver, set_paths as set_silver_paths


@pytest.fixture(scope="session")
def spark_init():
    spark, logger = utils.spark_init(app_name="TEST_WHO_Landing_to_Bronze")
    yield spark, logger
    if "DATABRICKS_RUNTIME_VERSION" not in os.environ:
        spark.stop()


def test_run_01_who_bronze(spark_init):
    """Test run_who_bronze"""

    # Set variables
    spark, logger = spark_init
    test_base_path = f"file:{os.path.join(os.path.dirname(os.path.abspath(__file__)), 'test_data')}"
    paths = set_bronze_paths(test_base_path)

    # Run pipeline
    who_landing_to_bronze(spark, test_base_path)

    # Load results
    test_df = spark.read.format("delta").load(paths['bronze_table_path'])

    # Check row count
    assert test_df.count() == 7

    # Check schema
    assert 'GHO_CODE' in test_df.schema.names


def test_run_02_who_silver(spark_init):
    """Test run_who_silver"""

    # Set variables
    spark, logger = spark_init
    test_base_path = f"file:{os.path.join(os.path.dirname(os.path.abspath(__file__)), 'test_data')}"
    paths = set_silver_paths(test_base_path)
    database_name = "testdb"
    spark.sql(f"CREATE DATABASE IF NOT EXISTS {database_name}")

    # Run pipeline
    who_bronze_to_silver(spark, test_base_path, database_name)

    # Load results
    test_df = spark.read.format("delta").load(paths['silver_table_path'])

    # Check row count
    assert test_df.count() == 6

    # Check schema
    assert 'Indicator' in test_df.schema.names
