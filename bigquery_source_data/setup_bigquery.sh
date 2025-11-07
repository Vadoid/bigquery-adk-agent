#!/bin/bash

# Script to set up BigQuery dataset and tables from CSV files
# This script creates the dataset, loads CSV files as tables, and creates a view
#
# IMPORTANT: Run this script OUTSIDE of any virtual environment to avoid
# conflicts with gcloud/bq Python dependencies.

set -e  # Exit on error

# Check if we're in a virtual environment and warn
if [ -n "$VIRTUAL_ENV" ]; then
    echo "⚠️  WARNING: Virtual environment detected: $VIRTUAL_ENV"
    echo "⚠️  Please deactivate it first: deactivate"
    echo "⚠️  gcloud/bq commands can conflict with venv Python packages"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please run: deactivate && ./setup_bigquery.sh"
        exit 1
    fi
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment variables from .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Source the .env file to load variables
    set -a  # automatically export all variables
    source "$PROJECT_ROOT/.env"
    set +a  # stop automatically exporting
else
    echo "Error: .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Check required environment variables
if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
    echo "Error: GOOGLE_CLOUD_PROJECT not set in .env file"
    exit 1
fi

# Use BIGQUERY_DATASET from .env or default to icecream_lab
DATASET_NAME="${BIGQUERY_DATASET:-icecream_lab}"
PROJECT_ID="$GOOGLE_CLOUD_PROJECT"
# bq commands use project:dataset format, not project.dataset
DATASET_ID="${PROJECT_ID}:${DATASET_NAME}"

echo "=========================================="
echo "BigQuery Dataset Setup"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Dataset: $DATASET_NAME"
echo "Full Dataset ID: $DATASET_ID"
echo "=========================================="
echo ""

# Step 1: Create dataset if it doesn't exist
echo "Step 1: Creating dataset (if it doesn't exist)..."
# bq mk uses project:dataset format
bq mk --dataset \
    --location=US \
    --description="Ice cream sales and customer data" \
    "$DATASET_ID" 2>/dev/null && echo "✅ Dataset created" || echo "ℹ️  Dataset already exists or error occurred (this is OK if it already exists)"
echo ""

# Step 2: Create tables from CSV files
echo "Step 2: Creating tables from CSV files..."

# Table 1: CustomerCases
echo "  Creating CustomerCases table..."
bq load \
    --source_format=CSV \
    --skip_leading_rows=1 \
    --autodetect \
    --replace \
    "${DATASET_ID}.CustomerCases" \
    "$SCRIPT_DIR/CustomerCases.csv"
echo "  ✅ CustomerCases table created"

# Table 2: MaterialMasterData
echo "  Creating MaterialMasterData table..."
bq load \
    --source_format=CSV \
    --skip_leading_rows=1 \
    --autodetect \
    --replace \
    "${DATASET_ID}.MaterialMasterData" \
    "$SCRIPT_DIR/MaterialMasterData.csv"
echo "  ✅ MaterialMasterData table created"

# Table 3: icecream_sales
echo "  Creating icecream_sales table..."
bq load \
    --source_format=CSV \
    --skip_leading_rows=1 \
    --autodetect \
    --replace \
    "${DATASET_ID}.icecream_sales" \
    "$SCRIPT_DIR/Icecream_sales.csv"
echo "  ✅ icecream_sales table created"
echo ""

# Step 3: Create view fda_ice_cream_enforcements
echo "Step 3: Creating fda_ice_cream_enforcements view..."
# Delete view if it exists, then create it
bq rm -f "${DATASET_ID}.fda_ice_cream_enforcements" 2>/dev/null || true
bq mk --use_legacy_sql=false \
    --view "
SELECT
  * -- Selects all columns from the source table
FROM
  \`bigquery-public-data.fda_food.food_enforcement\`
WHERE
  product_description LIKE '%ice cream%'
" \
    "${DATASET_ID}.fda_ice_cream_enforcements"
echo "  ✅ fda_ice_cream_enforcements view created"
echo ""

# Step 4: Create view actuals_vs_forecast
echo "Step 4: Creating actuals_vs_forecast view with AI forecast..."
# Delete view if it exists, then create it
bq rm -f "${DATASET_ID}.actuals_vs_forecast" 2>/dev/null || true

# Create the view with forecast query and union
bq mk --use_legacy_sql=false \
    --view "
WITH
  sales_data AS (
    SELECT 
      EXTRACT(DATE FROM SaleDate) AS date, 
      MaterialNumber, 
      SUM(SalesQuantity) AS sales_quantity
    FROM 
      \`${PROJECT_ID}.${DATASET_NAME}.icecream_sales\`
    GROUP BY date, MaterialNumber
  ),
  forecast_data AS (
    SELECT *
    FROM
      AI.FORECAST(
        TABLE sales_data,
        data_col => 'sales_quantity',
        timestamp_col => 'date',
        id_cols => ['MaterialNumber'],
        horizon => 30
      )
  )
SELECT
  t1.SaleDate AS event_timestamp,
  t1.MaterialNumber,
  SUM(t1.SalesQuantity) AS quantity_value,
  NULL AS confidence_level,
  NULL AS prediction_interval_lower_bound,
  NULL AS prediction_interval_upper_bound,
  NULL AS ai_forecast_status,
  'Actual' AS data_type
FROM
  \`${PROJECT_ID}.${DATASET_NAME}.icecream_sales\` AS t1
GROUP BY t1.SaleDate, t1.MaterialNumber
UNION ALL
SELECT
  t2.forecast_timestamp AS event_timestamp,
  t2.MaterialNumber,
  CAST(t2.forecast_value AS INT64) AS quantity_value,
  t2.confidence_level,
  t2.prediction_interval_lower_bound,
  t2.prediction_interval_upper_bound,
  t2.ai_forecast_status,
  'Forecast' AS data_type
FROM
  forecast_data AS t2
" \
    "${DATASET_ID}.actuals_vs_forecast"
echo "  ✅ actuals_vs_forecast view created"
echo ""

echo "=========================================="
echo "✅ Setup complete!"
echo "=========================================="
echo "Dataset: $DATASET_ID"
echo "Tables created:"
echo "  - CustomerCases"
echo "  - MaterialMasterData"
echo "  - icecream_sales"
echo "Views created:"
echo "  - fda_ice_cream_enforcements"
echo "  - actuals_vs_forecast (with AI forecast)"
echo "=========================================="

