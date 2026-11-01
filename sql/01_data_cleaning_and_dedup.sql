/* =====================================================================
   E-Commerce Customer Analytics: data cleaning in SQL Server
   Source: Online Retail II (two yearly sheets imported as
           dbo.[Year 2009-2010] and dbo.[Year 2010-11])
   Output: dbo.RetailCleaned (combined, typed, de-duplicated)
   ===================================================================== */

CREATE DATABASE EcommerceCustomerAnalytics;
GO
USE EcommerceCustomerAnalytics;
GO

-- 0. Row counts of the two raw sheets
SELECT COUNT(*) AS rows_2009_2010 FROM dbo.[Year 2009-2010];
SELECT COUNT(*) AS rows_2010_2011 FROM dbo.[Year 2010-11];

-- 1. Combine both sheets and convert data types
--    (dates arrive in two text formats, so both are tried)
SELECT Invoice, StockCode, Description, Quantity,
       COALESCE(
           TRY_CONVERT(datetime2, InvoiceDate, 120),
           TRY_CONVERT(datetime2, InvoiceDate, 105)
       ) AS InvoiceDate,
       TRY_CONVERT(decimal(10,2), Price) AS Price,
       Customer_ID, Country, '2009-2010' AS SourceSheet
INTO dbo.RetailCombined
FROM dbo.[Year 2009-2010]

UNION ALL

SELECT Invoice, StockCode, Description, Quantity,
       COALESCE(
           TRY_CONVERT(datetime2, InvoiceDate, 120),
           TRY_CONVERT(datetime2, InvoiceDate, 105)
       ) AS InvoiceDate,
       TRY_CONVERT(decimal(10,2), Price) AS Price,
       Customer_ID, Country, '2010-2011' AS SourceSheet
FROM dbo.[Year 2010-11];

-- 2. Conversion checks
SELECT COUNT(*) AS Total_rows    FROM dbo.RetailCombined;
SELECT COUNT(*) AS Failed_dates  FROM dbo.RetailCombined WHERE InvoiceDate IS NULL;
SELECT COUNT(*) AS Failed_prices FROM dbo.RetailCombined WHERE Price IS NULL;

-- 3. Data-quality checks
-- Check 1: missing Customer_ID
SELECT COUNT(*) AS missing_id FROM dbo.RetailCombined
WHERE Customer_ID IS NULL;

-- Check 2: negative or zero quantity (returns / cancellations)
SELECT COUNT(*) AS negative_quantity FROM dbo.RetailCombined
WHERE Quantity <= 0;

-- Check 3: missing description
SELECT COUNT(*) AS missing_description FROM dbo.RetailCombined
WHERE Description IS NULL;

-- Check 4: exact duplicate rows
SELECT Invoice, StockCode, Description, Quantity, InvoiceDate, Price,
       Customer_ID, Country, COUNT(*) AS exact_duplicate_count
FROM dbo.RetailCombined
GROUP BY Invoice, StockCode, Description, Quantity, InvoiceDate, Price,
         Customer_ID, Country
HAVING COUNT(*) > 1;

-- 4. Remove exact duplicates and create the final cleaned table
IF OBJECT_ID('dbo.RetailCleaned', 'U') IS NOT NULL
    DROP TABLE dbo.RetailCleaned;

WITH Deduped AS
(
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY Invoice, StockCode, Description, Quantity,
                            InvoiceDate, Price, Customer_ID, Country, SourceSheet
               ORDER BY (SELECT NULL)
           ) AS RowNum
    FROM dbo.RetailCombined
)
SELECT Invoice, StockCode, Description, Quantity, InvoiceDate, Price,
       Customer_ID, Country, SourceSheet
INTO dbo.RetailCleaned
FROM Deduped
WHERE RowNum = 1;

-- 5. Final check
SELECT COUNT(*) AS cleaned_rows FROM dbo.RetailCleaned;
