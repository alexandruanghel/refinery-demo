import os
from setuptools import setup

VERSION = "0.0.1"
if "LAKEHOUSE_VERSION" in os.environ:
    VERSION = os.environ["LAKEHOUSE_VERSION"]

setup(
    name='lakehousePipelines',
    version=VERSION,
    packages=['.lakehousePipelines'],
    entry_points={
        'console_scripts': [
            'bronze_countries = lakehousePipelines.bronze_countries:main',
            'bronze_customers = lakehousePipelines.bronze_customers:main',
            'bronze_fraud_reports = lakehousePipelines.bronze_fraud_reports:main',
            'bronze_transactions = lakehousePipelines.bronze_transactions:main',
            'silver_countries = lakehousePipelines.silver_countries:main',
            'silver_customers = lakehousePipelines.silver_customers:main',
            'silver_transactions = lakehousePipelines.silver_transactions:main',
        ]
    }
)
