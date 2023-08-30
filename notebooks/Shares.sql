-- Databricks notebook source
CREATE WIDGET TEXT database DEFAULT "main.default"

-- COMMAND ----------

-- MAGIC %sql
-- MAGIC SELECT * FROM ${database}.gold_aggregated_transactions LIMIT 5

-- COMMAND ----------

CREATE SHARE IF NOT EXISTS Refinery_Azure

-- COMMAND ----------

ALTER SHARE Refinery_Azure REMOVE TABLE ${database}.gold_aggregated_transactions

-- COMMAND ----------

ALTER SHARE Refinery_Azure ADD TABLE ${database}.gold_aggregated_transactions

-- COMMAND ----------

SHOW SHARES

-- COMMAND ----------


