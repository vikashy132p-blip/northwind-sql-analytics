/*===============================================================
 Project : Northwind SQL Analytics
 File    : Northwind_SQL_Analytics.sql
 Purpose : Full pipeline - data profiling, cleaning, fact table
           build, and all business analysis queries.
===============================================================*/

USE MyDatabase;
GO

/*===============================================================
 Project : Northwind SQL Analytics
 File    : 01_data_profiling.sql
 Purpose : Assess raw data quality across all source tables
           before running any cleaning or transformation steps.
===============================================================*/

-- Quick look at raw source tables
SELECT * FROM Orders;
SELECT * FROM OrderDetails;
SELECT * FROM Customers;
SELECT * FROM Products;


/*===============================================================
 1. Orders - NULL Profile
===============================================================*/
SELECT
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN OrderID       IS NULL THEN 1 ELSE 0 END)       AS orderid_null,
    SUM(CASE WHEN CustomerID    IS NULL THEN 1 ELSE 0 END)       AS customerid_null,
    SUM(CASE WHEN EmployeeID    IS NULL THEN 1 ELSE 0 END)       AS employeeid_null,
    SUM(CASE WHEN OrderDate     IS NULL THEN 1 ELSE 0 END)       AS orderdate_null,
    SUM(CASE WHEN RequiredDate  IS NULL THEN 1 ELSE 0 END)       AS requireddate_null,
    SUM(CASE WHEN ShippedDate   IS NULL THEN 1 ELSE 0 END)       AS shippeddate_null,
    SUM(CASE WHEN ShipVia       IS NULL THEN 1 ELSE 0 END)       AS shipvia_null,
    SUM(CASE WHEN Freight       IS NULL THEN 1 ELSE 0 END)       AS freight_null,
    SUM(CASE WHEN ShipName      IS NULL THEN 1 ELSE 0 END)       AS shipname_null,
    SUM(CASE WHEN ShipAddress   IS NULL THEN 1 ELSE 0 END)       AS shipaddress_null,
    SUM(CASE WHEN ShipCity      IS NULL THEN 1 ELSE 0 END)       AS shipcity_null,
    SUM(CASE WHEN ShipRegion    IS NULL THEN 1 ELSE 0 END)       AS shipregion_null,
    SUM(CASE WHEN ShipPostalCode IS NULL THEN 1 ELSE 0 END)      AS shippostalcode_null,
    SUM(CASE WHEN ShipCountry   IS NULL THEN 1 ELSE 0 END)       AS shipcountry_null
FROM Orders;

-- Findings:
--   21 NULLs  in ShippedDate     (unshipped / pending orders)
--   19 NULLs  in ShipPostalCode
--   507 NULLs in ShipRegion


/*===============================================================
 2. Order Details - NULL Profile
===============================================================*/
SELECT
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN OrderID   IS NULL THEN 1 ELSE 0 END)           AS orderid_null,
    SUM(CASE WHEN ProductID IS NULL THEN 1 ELSE 0 END)           AS productid_null,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END)           AS unitprice_null,
    SUM(CASE WHEN Quantity  IS NULL THEN 1 ELSE 0 END)           AS quantity_null
FROM OrderDetails;

-- Findings: no NULL values found.


/*===============================================================
 3. Customers - NULL Profile
===============================================================*/
SELECT
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN CustomerID   IS NULL THEN 1 ELSE 0 END)        AS customerid_null,
    SUM(CASE WHEN CompanyName  IS NULL THEN 1 ELSE 0 END)        AS companyname_null,
    SUM(CASE WHEN ContactName  IS NULL THEN 1 ELSE 0 END)        AS contactname_null,
    SUM(CASE WHEN ContactTitle IS NULL THEN 1 ELSE 0 END)        AS contacttitle_null,
    SUM(CASE WHEN Address      IS NULL THEN 1 ELSE 0 END)        AS address_null,
    SUM(CASE WHEN City         IS NULL THEN 1 ELSE 0 END)        AS city_null,
    SUM(CASE WHEN Region       IS NULL THEN 1 ELSE 0 END)        AS region_null,
    SUM(CASE WHEN PostalCode   IS NULL THEN 1 ELSE 0 END)        AS postalcode_null,
    SUM(CASE WHEN Country      IS NULL THEN 1 ELSE 0 END)        AS country_null,
    SUM(CASE WHEN Phone        IS NULL THEN 1 ELSE 0 END)        AS phone_null,
    SUM(CASE WHEN Fax          IS NULL THEN 1 ELSE 0 END)        AS fax_null
FROM Customers;

-- Findings:
--   60 NULLs in Region
--   1  NULL  in PostalCode
--   22 NULLs in Fax


/*===============================================================
 4. Products - NULL Profile
===============================================================*/
SELECT
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN ProductID       IS NULL THEN 1 ELSE 0 END)     AS productid_null,
    SUM(CASE WHEN ProductName     IS NULL THEN 1 ELSE 0 END)     AS productname_null,
    SUM(CASE WHEN SupplierID      IS NULL THEN 1 ELSE 0 END)     AS supplierid_null,
    SUM(CASE WHEN CategoryID      IS NULL THEN 1 ELSE 0 END)     AS categoryid_null,
    SUM(CASE WHEN QuantityPerUnit IS NULL THEN 1 ELSE 0 END)     AS quantityperunit_null,
    SUM(CASE WHEN UnitPrice       IS NULL THEN 1 ELSE 0 END)     AS unitprice_null,
    SUM(CASE WHEN UnitsInStock    IS NULL THEN 1 ELSE 0 END)     AS unitsinstock_null,
    SUM(CASE WHEN UnitsOnOrder    IS NULL THEN 1 ELSE 0 END)     AS unitsonorder_null,
    SUM(CASE WHEN ReorderLevel    IS NULL THEN 1 ELSE 0 END)     AS reorderlevel_null,
    SUM(CASE WHEN Discontinued    IS NULL THEN 1 ELSE 0 END)     AS discontinued_null
FROM Products;

-- Findings: no NULL values found.
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 02_data_cleaning.sql
 Purpose : Build clean staging tables from raw source tables and
           add derived columns needed for downstream analysis.

 Performance notes:
   - All derived columns are computed in the initial SELECT INTO
     (a single pass) instead of separate ALTER TABLE + UPDATE
     statements (which would mean one extra full table scan and
     write per column).
   - A clustered index is added on each staging table's natural
     key immediately after creation, since SELECT INTO produces
     a heap table with no indexes at all. Every join in
     03_build_fact_table.sql depends on these.
===============================================================*/

/*===============================================================
 1. Clean_Orders
    Missing ShipRegion / ShipPostalCode -> 'UNKNOWN'.
    Date parts, weekday name, order status, and shipping days are
    all computed here in one pass rather than added later.
===============================================================*/
IF OBJECT_ID('dbo.Clean_Orders', 'U') IS NOT NULL DROP TABLE dbo.Clean_Orders;
GO

SELECT
    OrderID,
    CustomerID,
    EmployeeID,
    OrderDate,
    RequiredDate,
    ShippedDate,
    ShipVia,
    Freight,
    ShipName,
    ShipAddress,
    ShipCity,
    COALESCE(ShipRegion, 'UNKNOWN')      AS ShipRegion,
    COALESCE(ShipPostalCode, 'UNKNOWN')  AS ShipPostalCode,
    ShipCountry,
    YEAR(OrderDate)                      AS YearOrderDate,
    MONTH(OrderDate)                     AS MonthOrderDate,
    DAY(OrderDate)                       AS DayOrderDate,
    DATENAME(WEEKDAY, OrderDate)         AS WeekdayOrderDate,
    CASE WHEN ShippedDate IS NULL THEN 'Pending' ELSE 'Shipped' END AS OrderStatus,
    CASE WHEN ShippedDate IS NOT NULL
         THEN DATEDIFF(DAY, OrderDate, ShippedDate)
         ELSE NULL
    END                                   AS ShippingDays
INTO Clean_Orders
FROM Orders;

-- OrderID is the natural key; every downstream join uses it.
CREATE UNIQUE CLUSTERED INDEX IX_CleanOrders_OrderID ON Clean_Orders (OrderID);

-- Supports country-wise / monthly shipping and trend queries.
CREATE NONCLUSTERED INDEX IX_CleanOrders_ShipCountry ON Clean_Orders (ShipCountry);
CREATE NONCLUSTERED INDEX IX_CleanOrders_YearMonth   ON Clean_Orders (YearOrderDate, MonthOrderDate);
CREATE NONCLUSTERED INDEX IX_CleanOrders_EmployeeID  ON Clean_Orders (EmployeeID);
GO


/*===============================================================
 2. Clean_Customers
    Missing Region / PostalCode -> 'UNKNOWN'; missing Fax ->
    'Not Available'.
===============================================================*/
IF OBJECT_ID('dbo.Clean_Customers', 'U') IS NOT NULL DROP TABLE dbo.Clean_Customers;
GO

SELECT
    CustomerID,
    CompanyName,
    ContactName,
    ContactTitle,
    Address,
    City,
    COALESCE(Region, 'UNKNOWN')      AS Region,
    COALESCE(PostalCode, 'UNKNOWN')  AS PostalCode,
    Country,
    Phone,
    COALESCE(Fax, 'Not Available')   AS Fax
INTO Clean_Customers
FROM Customers;

CREATE UNIQUE CLUSTERED INDEX IX_CleanCustomers_CustomerID ON Clean_Customers (CustomerID);
GO


/*===============================================================
 3. Clean_Products
===============================================================*/
IF OBJECT_ID('dbo.Clean_Products', 'U') IS NOT NULL DROP TABLE dbo.Clean_Products;
GO

SELECT *
INTO Clean_Products
FROM Products;

CREATE UNIQUE CLUSTERED INDEX IX_CleanProducts_ProductID ON Clean_Products (ProductID);
GO


/*===============================================================
 4. Clean_OrderDetails
    Revenue columns computed in the initial SELECT INTO instead
    of via three separate ALTER + UPDATE passes.
===============================================================*/
IF OBJECT_ID('dbo.Clean_OrderDetails', 'U') IS NOT NULL DROP TABLE dbo.Clean_OrderDetails;
GO

SELECT
    OrderID,
    ProductID,
    UnitPrice,
    Quantity,
    Discount,
    CAST(UnitPrice * Quantity AS FLOAT)                                                    AS GrossRevenue,
    CAST(ROUND(UnitPrice * Quantity * Discount, 2) AS FLOAT)                                AS DiscountedAmount,
    CAST(ROUND((UnitPrice * Quantity) - ROUND(UnitPrice * Quantity * Discount, 2), 2) AS FLOAT) AS NetRevenue
INTO Clean_OrderDetails
FROM OrderDetails;

-- Composite natural key; also the exact shape needed by the
-- basket-analysis self-join in 04_revenue_and_product_analysis.sql.
CREATE UNIQUE CLUSTERED INDEX IX_CleanOrderDetails_OrderProduct
    ON Clean_OrderDetails (OrderID, ProductID);

CREATE NONCLUSTERED INDEX IX_CleanOrderDetails_ProductID ON Clean_OrderDetails (ProductID);
GO


-- Sanity check
SELECT * FROM Clean_Orders;
SELECT * FROM Clean_OrderDetails;
SELECT * FROM Clean_Customers;
SELECT * FROM Clean_Products;
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 03_build_fact_table.sql
 Purpose : Join all cleaned staging tables into a single
           denormalized FactSales table for analytics.

 Performance notes:
   - The join keys (Clean_Orders.OrderID, Clean_OrderDetails
     .OrderID/.ProductID, Clean_Customers.CustomerID,
     Clean_Products.ProductID) are all indexed in
     02_data_cleaning.sql, so this join drives off index seeks
     rather than table scans.
   - FactSales itself is a heap after SELECT INTO; indexes are
     added below for the columns every downstream script filters
     or groups on (OrderID/ProductID for basket analysis,
     CustomerID, EmployeeID, OrderYear/Month, ShipCountry).
===============================================================*/

IF OBJECT_ID('dbo.FactSales', 'U') IS NOT NULL DROP TABLE dbo.FactSales;
GO

SELECT
    o.OrderID,
    o.CustomerID,
    o.EmployeeID,
    o.OrderDate,
    o.RequiredDate,
    o.ShippedDate,
    o.ShipVia,
    o.Freight,
    o.ShipName,
    o.ShipAddress,
    o.ShipCity,
    o.ShipRegion,
    o.ShipPostalCode,
    o.ShipCountry,
    o.YearOrderDate       AS OrderYear,
    o.MonthOrderDate       AS OrderMonth,
    o.DayOrderDate         AS OrderDay,
    o.WeekdayOrderDate,
    o.OrderStatus,
    o.ShippingDays,

    od.ProductID,
    od.UnitPrice,
    od.Quantity,
    od.Discount,
    od.GrossRevenue,
    od.DiscountedAmount    AS DiscountAmount,
    od.NetRevenue,

    c.CompanyName,
    c.ContactName,
    c.ContactTitle,
    c.Address               AS CusAddress,
    c.City                  AS CustomerCity,
    c.Region                 AS CustomerRegion,
    c.PostalCode              AS CustomerPostalCode,
    c.Country                AS CustomerCountry,
    c.Phone                  AS CustomerPhone,
    c.Fax                    AS CustomerFax,

    p.ProductName,
    p.SupplierID,
    p.CategoryID,
    p.QuantityPerUnit,
    p.UnitsInStock,
    p.UnitsOnOrder,
    p.ReorderLevel,
    p.Discontinued
INTO FactSales
FROM Clean_Orders o
JOIN Clean_OrderDetails od ON o.OrderID = od.OrderID
JOIN Clean_Customers c     ON o.CustomerID = c.CustomerID
JOIN Clean_Products p      ON od.ProductID = p.ProductID;


-- Line-item grain natural key; also serves the basket-analysis
-- self-join (04) which filters/joins on OrderID + ProductID.
CREATE UNIQUE CLUSTERED INDEX IX_FactSales_OrderProduct
    ON FactSales (OrderID, ProductID);

CREATE NONCLUSTERED INDEX IX_FactSales_CustomerID   ON FactSales (CustomerID)      INCLUDE (NetRevenue);
CREATE NONCLUSTERED INDEX IX_FactSales_EmployeeID    ON FactSales (EmployeeID)      INCLUDE (NetRevenue);
CREATE NONCLUSTERED INDEX IX_FactSales_ProductName   ON FactSales (ProductName)     INCLUDE (NetRevenue, Quantity);
CREATE NONCLUSTERED INDEX IX_FactSales_OrderYearMonth ON FactSales (OrderYear, OrderMonth) INCLUDE (NetRevenue);
CREATE NONCLUSTERED INDEX IX_FactSales_ShipCountry   ON FactSales (ShipCountry);
CREATE NONCLUSTERED INDEX IX_FactSales_CategoryID    ON FactSales (CategoryID)      INCLUDE (NetRevenue);
GO


-- Sanity check
SELECT * FROM FactSales;
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 04_revenue_and_product_analysis.sql
 Purpose : Revenue trends and product performance analysis
           built on top of FactSales.

 Performance notes:
   - Product Contribution % now uses SUM(NetRevenue) OVER () to
     compute the grand total once per query, instead of a scalar
     subquery re-scanning FactSales on every output row.
   - Basket analysis benefits from the clustered
     (OrderID, ProductID) index created in 03_build_fact_table.sql.
===============================================================*/

/*===============================================================
 1. Total Revenue
===============================================================*/
SELECT SUM(NetRevenue) AS TotalRevenue
FROM FactSales;


/*===============================================================
 2. Monthly Sales Trend
===============================================================*/
SELECT
    OrderYear,
    OrderMonth,
    SUM(NetRevenue) AS MonthlyRevenue
FROM FactSales
GROUP BY OrderYear, OrderMonth
ORDER BY OrderYear, OrderMonth;


/*===============================================================
 3. Quarterly Growth
===============================================================*/
SELECT
    OrderYear,
    DATEPART(QUARTER, OrderDate) AS Quarter,
    SUM(NetRevenue)              AS QuarterlyRevenue
FROM FactSales
GROUP BY OrderYear, DATEPART(QUARTER, OrderDate)
ORDER BY OrderYear, DATEPART(QUARTER, OrderDate);


/*===============================================================
 4. Yearly Growth
===============================================================*/
SELECT
    OrderYear,
    SUM(NetRevenue) AS YearlyRevenue
FROM FactSales
GROUP BY OrderYear
ORDER BY OrderYear;


/*===============================================================
 5. Top 5 Selling Products
===============================================================*/
SELECT TOP 5
    ProductName,
    SUM(NetRevenue) AS RevenueByProduct
FROM FactSales
GROUP BY ProductName
ORDER BY SUM(NetRevenue) DESC;


/*===============================================================
 6. Lowest 5 Selling Products
===============================================================*/
SELECT TOP 5
    ProductName,
    SUM(NetRevenue) AS RevenueByProduct
FROM FactSales
GROUP BY ProductName
ORDER BY SUM(NetRevenue);


/*===============================================================
 7. Product Revenue Contribution %
    Grand total computed once via window function rather than a
    per-row scalar subquery against FactSales.
===============================================================*/
WITH RevenueByProduct AS (
    SELECT ProductName, SUM(NetRevenue) AS ProductRevenue
    FROM FactSales
    GROUP BY ProductName
)
SELECT
    ProductName,
    ProductRevenue,
    CONCAT(ROUND(ProductRevenue * 100.0 / SUM(ProductRevenue) OVER (), 2), '%') AS PercentageContribution
FROM RevenueByProduct
ORDER BY ProductRevenue DESC;


/*===============================================================
 8. Best Sales Month for Each Product
===============================================================*/
WITH MonthlyRevenue AS (
    SELECT
        ProductName,
        YEAR(OrderDate)  AS Year,
        MONTH(OrderDate) AS Month,
        SUM(NetRevenue)  AS Revenue
    FROM FactSales
    GROUP BY ProductName, YEAR(OrderDate), MONTH(OrderDate)
),
RankedSales AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY ProductName ORDER BY Revenue DESC) AS Rank
    FROM MonthlyRevenue
)
SELECT ProductName, Year, Month, Revenue
FROM RankedSales
WHERE Rank = 1
ORDER BY Revenue DESC;


/*===============================================================
 9. Slow-Moving Products (Lowest Sales Quantity)
===============================================================*/
WITH RankedSales AS (
    SELECT
        ProductName,
        SUM(Quantity) AS TotalQuantity,
        DENSE_RANK() OVER (ORDER BY SUM(Quantity)) AS Rank
    FROM FactSales
    GROUP BY ProductName
)
SELECT ProductName, TotalQuantity, Rank
FROM RankedSales
WHERE Rank <= 5;


/*===============================================================
 10. Products Frequently Bought Together (Basket Analysis)
     The self-join drives off IX_FactSales_OrderProduct
     (clustered on OrderID, ProductID) rather than a full scan.
===============================================================*/
SELECT
    f1.ProductName AS ProductA,
    f2.ProductName AS ProductB,
    COUNT(*)        AS TimesBoughtTogether
FROM FactSales f1
JOIN FactSales f2
    ON f1.OrderID = f2.OrderID
    AND f1.ProductID < f2.ProductID
GROUP BY f1.ProductName, f2.ProductName
ORDER BY TimesBoughtTogether DESC;
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 05_customer_analytics.sql
 Purpose : Customer segmentation, RFM analysis, retention, and
           lifetime value metrics built on top of FactSales.

 Performance notes:
   - Recency segmentation previously called
     (SELECT MaxDate FROM LatestDate) three times per row; it's
     now computed once via CROSS JOIN.
   - Repeat purchase rate previously ran two independent scalar
     subqueries plus a CTE (3 scans of FactSales); it's now a
     single conditional-aggregation pass.
   - CustomerID is indexed on FactSales (03_build_fact_table.sql),
     so the JOINs in the RFM query use index seeks.
===============================================================*/

/*===============================================================
 1. High-Value Customers (Top 5 by Revenue)
===============================================================*/
SELECT TOP 5
    CustomerID,
    SUM(NetRevenue) AS RevenueByCustomer
FROM FactSales
GROUP BY CustomerID
ORDER BY SUM(NetRevenue) DESC;


/*===============================================================
 2. Repeat Customers (Top 5 by Order Count)
===============================================================*/
SELECT TOP 5
    CustomerID,
    COUNT(DISTINCT OrderID) AS TotalOrders
FROM FactSales
GROUP BY CustomerID
ORDER BY COUNT(DISTINCT OrderID) DESC;


/*===============================================================
 3. Revenue-Based Segmentation
===============================================================*/
SELECT
    CustomerID,
    SUM(NetRevenue) AS RevenueByCustomer,
    CASE
        WHEN SUM(NetRevenue) > 10000                THEN 'High Value'
        WHEN SUM(NetRevenue) BETWEEN 5000 AND 10000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS CustomerValue
FROM FactSales
GROUP BY CustomerID;


/*===============================================================
 4. Frequency-Based Segmentation
===============================================================*/
SELECT
    CustomerID,
    COUNT(DISTINCT OrderID) AS TotalOrders,
    CASE
        WHEN COUNT(DISTINCT OrderID) > 30                THEN 'Frequent Buyer'
        WHEN COUNT(DISTINCT OrderID) BETWEEN 15 AND 30    THEN 'Occasional Buyer'
        ELSE 'Rare Buyer'
    END AS FrequencyOfBuyers
FROM FactSales
GROUP BY CustomerID
ORDER BY FrequencyOfBuyers;



/*===============================================================
 5. Recency-Based Segmentation
    MAX(OrderDate) across the whole table is computed once
    (LatestDate) and joined in via CROSS JOIN, instead of being
    re-evaluated as a scalar subquery in every branch.
===============================================================*/
WITH LatestDate AS (
    SELECT MAX(OrderDate) AS MaxDate FROM FactSales
),
CustomerRecency AS (
    SELECT
        f.CustomerID,
        MAX(f.OrderDate) AS LatestOrderDate,
        DATEDIFF(DAY, MAX(f.OrderDate), l.MaxDate) AS RecencyDays
    FROM FactSales f
    CROSS JOIN LatestDate l
    GROUP BY f.CustomerID, l.MaxDate
)
SELECT
    CustomerID,
    LatestOrderDate,
    RecencyDays,
    CASE
        WHEN RecencyDays < 30                  THEN 'Active'
        WHEN RecencyDays BETWEEN 30 AND 60     THEN 'Warm'
        ELSE 'Inactive'
    END AS CustomerActivityStatus
FROM CustomerRecency;


/*===============================================================
 6. RFM (Recency, Frequency, Monetary) Segmentation
===============================================================*/

WITH customer_rfm AS
(
    SELECT
        CustomerID,

        DATEDIFF(
            DAY,
            MAX(OrderDate),
            MAX(MAX(OrderDate)) OVER ()
        ) AS RecencyDays,

        COUNT(DISTINCT OrderID) AS OrderFrequency,

        SUM(NetRevenue) AS CustomerMonetary

    FROM FactSales
    GROUP BY CustomerID
)

SELECT
    CustomerID,
    RecencyDays,
    OrderFrequency,
    CustomerMonetary,

    CASE
        WHEN RecencyDays < 30
             AND OrderFrequency > 20
             AND CustomerMonetary > 1000
            THEN 'VIP'

        WHEN RecencyDays BETWEEN 30 AND 90
            THEN 'Regular'

        ELSE 'Inactive'
    END AS Segment

FROM customer_rfm
ORDER BY CustomerID;

/*===============================================================
 7. Customer Repeat Purchase Rate
    Single pass with conditional aggregation, instead of two
    independent scalar subqueries plus a separate CTE (previously
    3 scans of FactSales).
===============================================================*/
WITH CustomerOrders AS (
    SELECT CustomerID, COUNT(DISTINCT OrderID) AS OrderCount
    FROM FactSales
    GROUP BY CustomerID
)
SELECT
    SUM(CASE WHEN OrderCount > 1 THEN 1 ELSE 0 END)                              AS RepeatedCustomerCount,
    COUNT(*)                                                                     AS TotalCustomerCount,
    ROUND(SUM(CASE WHEN OrderCount > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS RepeatPurchaseRate
FROM CustomerOrders;


/*===============================================================
 8. New vs Returning Customers by Month
===============================================================*/
WITH FirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate
    FROM FactSales
    GROUP BY CustomerID
),
CurrOrder AS (
    SELECT DISTINCT
        f.CustomerID,
        YEAR(f.OrderDate)         AS OrderYear,
        MONTH(f.OrderDate)        AS OrderMonth,
        YEAR(fo.FirstOrderDate)   AS FirstOrderYear,
        MONTH(fo.FirstOrderDate)  AS FirstOrderMonth
    FROM FactSales f
    JOIN FirstOrder fo ON f.CustomerID = fo.CustomerID
)
SELECT
    OrderYear,
    OrderMonth,
    SUM(CASE WHEN OrderYear = FirstOrderYear AND OrderMonth = FirstOrderMonth THEN 1 ELSE 0 END) AS NewCustomers,
    SUM(CASE WHEN OrderYear > FirstOrderYear
              OR (OrderYear = FirstOrderYear AND OrderMonth > FirstOrderMonth) THEN 1 ELSE 0 END) AS ReturningCustomers
FROM CurrOrder
GROUP BY OrderYear, OrderMonth
ORDER BY OrderYear, OrderMonth;


/*===============================================================
 9. Customer Lifetime Value (CLV)
===============================================================*/
SELECT
    CustomerID,
    SUM(NetRevenue) AS LifetimeRevenue
FROM FactSales
GROUP BY CustomerID;


/*===============================================================
 10. Average Order Value by Month
===============================================================*/
SELECT
    YEAR(OrderDate)              AS Year,
    MONTH(OrderDate)             AS Month,
    COUNT(DISTINCT OrderID)      AS TotalOrders,
    ROUND(SUM(NetRevenue) / COUNT(DISTINCT OrderID), 2) AS AvgOrderValue
FROM FactSales
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY YEAR(OrderDate), MONTH(OrderDate);
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 06_shipping_and_logistics.sql
 Purpose : Shipment timing and delivery performance analysis.

 Performance notes:
   - Every query here is order-level (one row per order), but
     FactSales is line-item grain (one row per order/product).
     Querying FactSales for order-level questions means running
     SELECT DISTINCT across a wide row set just to collapse
     duplicates back down - an expensive sort/dedup that also
     re-counts nothing correctly if line items differ.
   - All queries below source from Clean_Orders instead, which is
     already one row per order and has ShipCountry, OrderDate,
     RequiredDate, and ShippedDate on it directly. This avoids the
     DISTINCT entirely and uses the indexes already built in
     02_data_cleaning.sql (OrderID clustered key, plus
     ShipCountry / YearOrderDate+MonthOrderDate / EmployeeID).
===============================================================*/

/*===============================================================
 1. Average Shipping Time
===============================================================*/
SELECT AVG(ShippingDays * 1.0) AS AvgShippingDays
FROM Clean_Orders
WHERE ShippedDate IS NOT NULL;


/*===============================================================
 2. Delayed Shipments (per order)
===============================================================*/
SELECT
    OrderID,
    RequiredDate,
    ShippedDate,
    CASE
        WHEN ShippedDate IS NULL          THEN 'Pending'
        WHEN ShippedDate <= RequiredDate  THEN 'On Time'
        ELSE 'Delayed'
    END AS ShipmentStatus
FROM Clean_Orders;


/*===============================================================
 3. Country-Wise Shipping Performance
===============================================================*/
WITH ShippingPerformance AS (
    SELECT
        ShipCountry,
        OrderID,
        ShippingDays,
        CASE
            WHEN ShippedDate IS NULL         THEN 'Pending'
            WHEN ShippedDate <= RequiredDate THEN 'On Time'
            ELSE 'Delayed'
        END AS ShipmentStatus
    FROM Clean_Orders
)
SELECT
    ShipCountry,
    AVG(ShippingDays * 1.0)                                        AS AvgShippingDays,
    SUM(CASE WHEN ShipmentStatus = 'Delayed' THEN 1 ELSE 0 END)    AS DelayedOrders,
    SUM(CASE WHEN ShipmentStatus = 'On Time' THEN 1 ELSE 0 END)    AS OnTimeOrders,
    SUM(CASE WHEN ShipmentStatus = 'Pending' THEN 1 ELSE 0 END)    AS PendingOrders
FROM ShippingPerformance
GROUP BY ShipCountry
ORDER BY AvgShippingDays;


/*===============================================================
 4. Monthly Delayed Shipment Trend
===============================================================*/
SELECT
    YearOrderDate  AS OrderYear,
    MonthOrderDate AS OrderMonth,
    COUNT(*)                                                        AS TotalOrders,
    SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)     AS DelayedOrderCount,
    ROUND(SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS DelayedPercent
FROM Clean_Orders
GROUP BY YearOrderDate, MonthOrderDate
ORDER BY YearOrderDate, MonthOrderDate;


/*===============================================================
 5. Delayed Shipment Percentage by Country
    Single pass with conditional aggregation, instead of three
    separate CTEs each scanning the same table independently.
===============================================================*/
SELECT
    ShipCountry,
    COUNT(*)                                                        AS TotalOrderCount,
    SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END)     AS DelayedCount,
    ROUND(SUM(CASE WHEN ShippedDate > RequiredDate THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS DelayedPercent
FROM Clean_Orders
GROUP BY ShipCountry
ORDER BY DelayedPercent DESC;
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 07_advanced_analytics.sql
 Purpose : Window-function based analysis - running totals,
           growth rates, rankings, and Pareto (80/20) analysis.

 Performance notes:
   - Queries 7 and 8 previously each recomputed an identical
     "Contribution" CTE from scratch (two independent scans of
     FactSales for what is really one dataset). They're now
     combined into a single CTE that both the full contribution
     list and the Pareto-filtered list are built from.
===============================================================*/

/*===============================================================
 1. Running Total of Monthly Revenue
===============================================================*/
WITH SumRevenue AS (
    SELECT OrderYear, OrderMonth, SUM(NetRevenue) AS NetRevenueByMonth
    FROM FactSales
    GROUP BY OrderYear, OrderMonth
)
SELECT
    OrderYear,
    OrderMonth,
    NetRevenueByMonth,
    SUM(NetRevenueByMonth) OVER (ORDER BY OrderYear, OrderMonth) AS RunningMonthlyRevenue
FROM SumRevenue
ORDER BY OrderYear, OrderMonth;


/*===============================================================
 2. Month-over-Month Revenue Growth %
===============================================================*/
WITH SumRevenue AS (
    SELECT OrderYear, OrderMonth, SUM(NetRevenue) AS RevenueCurrentMonth
    FROM FactSales
    GROUP BY OrderYear, OrderMonth
),
MonthlyData AS (
    SELECT
        OrderYear,
        OrderMonth,
        RevenueCurrentMonth,
        LAG(RevenueCurrentMonth) OVER (ORDER BY OrderYear, OrderMonth) AS RevenuePreviousMonth
    FROM SumRevenue
)
SELECT
    OrderYear,
    OrderMonth,
    RevenueCurrentMonth,
    RevenuePreviousMonth,
    ROUND((RevenueCurrentMonth - RevenuePreviousMonth) * 100.0 / RevenuePreviousMonth, 2) AS PercentGrowth
FROM MonthlyData
ORDER BY OrderYear, OrderMonth;


/*===============================================================
 3. Year-over-Year Revenue Growth %
===============================================================*/
WITH SumRevenue AS (
    SELECT OrderYear, SUM(NetRevenue) AS CurrentYearRevenue
    FROM FactSales
    GROUP BY OrderYear
),
YearlyRevenue AS (
    SELECT
        OrderYear,
        CurrentYearRevenue,
        LAG(CurrentYearRevenue) OVER (ORDER BY OrderYear) AS PrevYearRevenue
    FROM SumRevenue
)
SELECT
    OrderYear,
    CurrentYearRevenue,
    PrevYearRevenue,
    ROUND((CurrentYearRevenue - PrevYearRevenue) * 100.0 / PrevYearRevenue, 2) AS PercentGrowth
FROM YearlyRevenue;


/*===============================================================
 4. Top 3 Products by Revenue, Each Year
===============================================================*/
WITH RevenueByProduct AS (
    SELECT OrderYear, ProductName, SUM(NetRevenue) AS NetRevenueByProduct
    FROM FactSales
    GROUP BY OrderYear, ProductName
),
Final AS (
    SELECT
        OrderYear,
        ProductName,
        NetRevenueByProduct,
        DENSE_RANK() OVER (PARTITION BY OrderYear ORDER BY NetRevenueByProduct DESC) AS Rank
    FROM RevenueByProduct
)
SELECT * FROM Final WHERE Rank <= 3;


/*===============================================================
 5. Top 3 Customers by Revenue, Each Country
===============================================================*/
WITH RevenueByCustomer AS (
    SELECT CustomerCountry, CustomerID, SUM(NetRevenue) AS NetRevenueByCustomer
    FROM FactSales
    GROUP BY CustomerCountry, CustomerID
),
Final AS (
    SELECT
        CustomerCountry,
        CustomerID,
        NetRevenueByCustomer,
        DENSE_RANK() OVER (PARTITION BY CustomerCountry ORDER BY NetRevenueByCustomer DESC) AS Rank
    FROM RevenueByCustomer
)
SELECT * FROM Final WHERE Rank <= 3;


/*===============================================================
 6. Product Revenue Rank Within Each Category
===============================================================*/
WITH Revenue AS (
    SELECT CategoryID, ProductName, SUM(NetRevenue) AS RevenueByProduct
    FROM FactSales
    GROUP BY CategoryID, ProductName
)
SELECT
    CategoryID,
    ProductName,
    RevenueByProduct,
    DENSE_RANK() OVER (PARTITION BY CategoryID ORDER BY RevenueByProduct DESC) AS Rank
FROM Revenue;


/*===============================================================
 7 & 8. Product Revenue Contribution % + Cumulative Contribution
        + Pareto Analysis (80/20)

        A CTE's scope in T-SQL is only the single statement that
        follows it, so it can't be reused across two separate
        SELECTs. A #temp table is used instead so the per-product
        revenue aggregation (the expensive part - a full scan +
        GROUP BY of FactSales) runs once and both outputs below
        read from the already-computed, indexed result.
===============================================================*/
IF OBJECT_ID('tempdb..#Contribution') IS NOT NULL DROP TABLE #Contribution;

SELECT
    ProductName,
    SUM(NetRevenue) AS ProductRevenue
INTO #Contribution
FROM FactSales
GROUP BY ProductName;

CREATE CLUSTERED INDEX IX_Temp_ProductRevenue ON #Contribution (ProductRevenue DESC);

-- 7. Full list, every product with its individual and cumulative contribution %
SELECT
    ProductName,
    ProductRevenue,
    ProductRevenue * 100.0 / SUM(ProductRevenue) OVER ()                              AS ProductContribution,
    SUM(ProductRevenue) OVER (ORDER BY ProductRevenue DESC) * 100.0
        / SUM(ProductRevenue) OVER ()                                                  AS CumulativeContribution
FROM #Contribution
ORDER BY ProductRevenue DESC;

-- 8. Pareto cut: products making up the first 80% of total revenue
WITH Final AS (
    SELECT
        ProductName,
        ProductRevenue,
        SUM(ProductRevenue) OVER (ORDER BY ProductRevenue DESC) * 100.0
            / SUM(ProductRevenue) OVER ()                                              AS CumulativeContribution
    FROM #Contribution
)
SELECT * FROM Final
WHERE CumulativeContribution <= 80;

DROP TABLE #Contribution;
/*===============================================================
 Project : Northwind SQL Analytics
 File    : 08_employee_performance.sql
 Purpose : Employee sales and shipping performance analysis.

 Performance notes:
   - Query 1 (sales) is genuinely a revenue question, so it stays
     on FactSales, which has an EmployeeID index with NetRevenue
     included (03_build_fact_table.sql).
   - Query 2 (shipping delay) is an order-level question and now
     sources from Clean_Orders instead of DISTINCT-ing FactSales
     down from line-item grain, using the existing EmployeeID
     index on Clean_Orders (02_data_cleaning.sql).
===============================================================*/

/*===============================================================
 1. Employee-Wise Sales Performance
===============================================================*/
SELECT
    EmployeeID,
    SUM(NetRevenue) AS TotalSales
FROM FactSales
GROUP BY EmployeeID
ORDER BY TotalSales DESC;


/*===============================================================
 2. Employee-Wise Average Shipping Delay
===============================================================*/
SELECT
    EmployeeID,
    COUNT(*)                                                      AS TotalDelayedOrders,
    AVG(DATEDIFF(DAY, RequiredDate, ShippedDate) * 1.0)            AS AvgDelayedDays
FROM Clean_Orders
WHERE ShippedDate > RequiredDate
GROUP BY EmployeeID
ORDER BY AvgDelayedDays DESC;
