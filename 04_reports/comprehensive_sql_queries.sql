-- =====================================================
-- COMPREHENSIVE SQL QUERIES FOR VENDOR PERFORMANCE ANALYSIS
-- =====================================================
-- Database: SQLite inventory.db
-- Purpose: Complete business intelligence and reporting queries

-- =====================================================
-- 1. EXECUTIVE DASHBOARD KPIs
-- =====================================================

-- Overall Business Metrics
SELECT 
    'Total Sales Revenue' as Metric,
    SUM(TotalSalesDollars) as Value,
    '$' || PRINTF('%,.2f', SUM(TotalSalesDollars)) as Formatted_Value
FROM vendor_sales_summary

UNION ALL

SELECT 
    'Total Purchase Cost' as Metric,
    SUM(TotalPurchaseDollars) as Value,
    '$' || PRINTF('%,.2f', SUM(TotalPurchaseDollars)) as Formatted_Value
FROM vendor_sales_summary

UNION ALL

SELECT 
    'Gross Profit' as Metric,
    SUM(TotalSalesDollars - TotalPurchaseDollars) as Value,
    '$' || PRINTF('%,.2f', SUM(TotalSalesDollars - TotalPurchaseDollars)) as Formatted_Value
FROM vendor_sales_summary

UNION ALL

SELECT 
    'Overall Profit Margin' as Metric,
    AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as Value,
    PRINTF('%.2f%%', AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars)) as Formatted_Value
FROM vendor_sales_summary
WHERE TotalSalesDollars > 0;

-- =====================================================
-- 2. VENDOR PERFORMANCE ANALYSIS
-- =====================================================

-- Top 10 Vendors by Sales Performance
WITH VendorPerformance AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalPurchaseDollars) as TotalPurchases,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as AvgTurnover,
        COUNT(DISTINCT Brand) as BrandCount,
        SUM(FreightCost) as TotalFreight
    FROM vendor_sales_summary
    GROUP BY VendorName
)
SELECT 
    VendorName,
    TotalSales,
    TotalPurchases,
    GrossProfit,
    ProfitMargin,
    AvgTurnover,
    BrandCount,
    TotalFreight,
    (TotalFreight * 100.0 / TotalPurchases) as FreightRatio,
    RANK() OVER (ORDER BY TotalSales DESC) as SalesRank,
    RANK() OVER (ORDER BY GrossProfit DESC) as ProfitRank
FROM VendorPerformance
ORDER BY TotalSales DESC
LIMIT 10;

-- Vendor Performance Categories
WITH VendorMetrics AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as AvgTurnover,
        COUNT(*) as ProductCount
    FROM vendor_sales_summary
    GROUP BY VendorName
),
VendorQuartiles AS (
    SELECT 
        VendorName,
        TotalSales,
        GrossProfit,
        ProfitMargin,
        AvgTurnover,
        ProductCount,
        NTILE(4) OVER (ORDER BY TotalSales) as SalesQuartile,
        NTILE(4) OVER (ORDER BY GrossProfit) as ProfitQuartile,
        NTILE(4) OVER (ORDER BY ProfitMargin) as MarginQuartile
    FROM VendorMetrics
)
SELECT 
    VendorName,
    TotalSales,
    GrossProfit,
    ProfitMargin,
    AvgTurnover,
    ProductCount,
    CASE 
        WHEN SalesQuartile = 4 AND ProfitQuartile = 4 THEN 'Star Performer'
        WHEN SalesQuartile = 4 AND ProfitQuartile <= 2 THEN 'High Volume, Low Margin'
        WHEN SalesQuartile <= 2 AND ProfitQuartile = 4 THEN 'High Margin, Niche Player'
        WHEN SalesQuartile <= 2 AND ProfitQuartile <= 2 THEN 'Underperformer'
        ELSE 'Average Performer'
    END as PerformanceCategory
FROM VendorQuartiles
ORDER BY TotalSales DESC;

-- =====================================================
-- 3. BRAND AND PRODUCT ANALYSIS
-- =====================================================

-- Top 20 Brands by Sales with Performance Metrics
SELECT 
    Description as BrandName,
    COUNT(DISTINCT VendorName) as VendorCount,
    SUM(TotalSalesDollars) as TotalSales,
    SUM(TotalPurchaseDollars) as TotalPurchases,
    SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
    AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
    SUM(TotalSalesQuantity) as TotalUnitsSold,
    SUM(TotalPurchaseQuantity) as TotalUnitsPurchased,
    AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as StockTurnover,
    AVG(PurchasePrice) as AvgPurchasePrice,
    AVG(TotalSalesPrice * 1.0 / TotalSalesQuantity) as AvgSellingPrice
FROM vendor_sales_summary
WHERE TotalSalesDollars > 0
GROUP BY Description
ORDER BY TotalSales DESC
LIMIT 20;

-- Brands Needing Promotional Support (High Margin, Low Sales)
WITH BrandMetrics AS (
    SELECT 
        Description,
        SUM(TotalSalesDollars) as TotalSales,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit
    FROM vendor_sales_summary
    WHERE TotalSalesDollars > 0
    GROUP BY Description
),
Thresholds AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY TotalSales) as LowSalesThreshold,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ProfitMargin) as HighMarginThreshold
    FROM BrandMetrics
)
SELECT 
    bm.Description,
    bm.TotalSales,
    bm.ProfitMargin,
    bm.GrossProfit,
    'Promotional Target' as Recommendation
FROM BrandMetrics bm, Thresholds t
WHERE bm.TotalSales < t.LowSalesThreshold 
  AND bm.ProfitMargin > t.HighMarginThreshold
ORDER BY bm.ProfitMargin DESC;

-- =====================================================
-- 4. INVENTORY AND SUPPLY CHAIN ANALYSIS
-- =====================================================

-- Inventory Turnover Analysis
WITH InventoryMetrics AS (
    SELECT 
        VendorName,
        Description,
        TotalPurchaseQuantity,
        TotalSalesQuantity,
        (TotalPurchaseQuantity - TotalSalesQuantity) as UnsoldQuantity,
        (TotalPurchaseQuantity - TotalSalesQuantity) * PurchasePrice as UnsoldInventoryValue,
        TotalSalesQuantity * 1.0 / TotalPurchaseQuantity as TurnoverRatio,
        CASE 
            WHEN TotalSalesQuantity * 1.0 / TotalPurchaseQuantity < 0.5 THEN 'Critical'
            WHEN TotalSalesQuantity * 1.0 / TotalPurchaseQuantity < 0.8 THEN 'Poor'
            WHEN TotalSalesQuantity * 1.0 / TotalPurchaseQuantity < 1.2 THEN 'Good'
            ELSE 'Excellent'
        END as TurnoverCategory
    FROM vendor_sales_summary
    WHERE TotalPurchaseQuantity > 0
)
SELECT 
    TurnoverCategory,
    COUNT(*) as ProductCount,
    SUM(UnsoldQuantity) as TotalUnsoldUnits,
    SUM(UnsoldInventoryValue) as TotalUnsoldValue,
    AVG(TurnoverRatio) as AvgTurnoverRatio
FROM InventoryMetrics
GROUP BY TurnoverCategory
ORDER BY 
    CASE TurnoverCategory
        WHEN 'Critical' THEN 1
        WHEN 'Poor' THEN 2
        WHEN 'Good' THEN 3
        WHEN 'Excellent' THEN 4
    END;

-- Vendors with Low Inventory Turnover
SELECT 
    VendorName,
    COUNT(*) as ProductCount,
    SUM(TotalPurchaseQuantity) as TotalPurchased,
    SUM(TotalSalesQuantity) as TotalSold,
    SUM(TotalPurchaseQuantity - TotalSalesQuantity) as UnsoldUnits,
    SUM((TotalPurchaseQuantity - TotalSalesQuantity) * PurchasePrice) as UnsoldValue,
    AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as AvgTurnover,
    SUM(TotalSalesDollars) as TotalSales,
    SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit
FROM vendor_sales_summary
WHERE TotalPurchaseQuantity > 0
  AND TotalSalesQuantity * 1.0 / TotalPurchaseQuantity < 1.0
GROUP BY VendorName
ORDER BY UnsoldValue DESC
LIMIT 15;

-- =====================================================
-- 5. FREIGHT AND OPERATIONAL EFFICIENCY
-- =====================================================

-- Freight Cost Analysis by Vendor
WITH VendorFreight AS (
    SELECT 
        VendorName,
        SUM(TotalPurchaseDollars) as TotalPurchases,
        SUM(FreightCost) as TotalFreight,
        SUM(FreightCost) * 100.0 / SUM(TotalPurchaseDollars) as FreightRatio,
        COUNT(*) as TransactionCount,
        AVG(FreightCost) as AvgFreightPerTransaction
    FROM vendor_sales_summary
    GROUP BY VendorName
)
SELECT 
    VendorName,
    TotalPurchases,
    TotalFreight,
    FreightRatio,
    TransactionCount,
    AvgFreightPerTransaction,
    CASE 
        WHEN FreightRatio > 5.0 THEN 'High'
        WHEN FreightRatio > 3.0 THEN 'Medium'
        ELSE 'Low'
    END as FreightCostCategory,
    RANK() OVER (ORDER BY FreightRatio DESC) as FreightRiskRank
FROM VendorFreight
ORDER BY FreightRatio DESC;

-- Bulk Purchase Impact Analysis
WITH OrderSizeCategories AS (
    SELECT 
        VendorName,
        Description,
        TotalPurchaseQuantity,
        CASE 
            WHEN TotalPurchaseQuantity <= (SELECT PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY TotalPurchaseQuantity) FROM vendor_sales_summary) THEN 'Small'
            WHEN TotalPurchaseQuantity <= (SELECT PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY TotalPurchaseQuantity) FROM vendor_sales_summary) THEN 'Medium'
            ELSE 'Large'
        END as OrderSize,
        PurchasePrice as UnitCost
    FROM vendor_sales_summary
    WHERE TotalPurchaseQuantity > 0
)
SELECT 
    OrderSize,
    COUNT(*) as TransactionCount,
    AVG(UnitCost) as AvgUnitCost,
    MIN(UnitCost) as MinUnitCost,
    MAX(UnitCost) as MaxUnitCost,
    (SELECT AVG(UnitCost) FROM OrderSizeCategories WHERE OrderSize = 'Small') - 
    (SELECT AVG(UnitCost) FROM OrderSizeCategories WHERE OrderSize = 'Large') as SmallVsLargeSavings
FROM OrderSizeCategories
GROUP BY OrderSize
ORDER BY 
    CASE OrderSize
        WHEN 'Small' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Large' THEN 3
    END;

-- =====================================================
-- 6. MARKET CONCENTRATION AND RISK ANALYSIS
-- =====================================================

-- Market Concentration Metrics
WITH VendorMarketShare AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as VendorSales,
        SUM(TotalSalesDollars) * 100.0 / (SELECT SUM(TotalSalesDollars) FROM vendor_sales_summary) as MarketShare
    FROM vendor_sales_summary
    GROUP BY VendorName
),
ConcentrationMetrics AS (
    SELECT 
        SUM(CASE WHEN rn <= 4 THEN MarketShare ELSE 0 END) as CR4,
        SUM(CASE WHEN rn <= 10 THEN MarketShare ELSE 0 END) as CR10,
        SUM(MarketShare * MarketShare) as HHI
    FROM (
        SELECT *, 
               ROW_NUMBER() OVER (ORDER BY VendorSales DESC) as rn
        FROM VendorMarketShare
    )
)
SELECT 
    'CR4 (Top 4 Vendors)' as Metric,
    CR4 as Value,
    PRINTF('%.2f%%', CR4) as Formatted_Value
FROM ConcentrationMetrics

UNION ALL

SELECT 
    'CR10 (Top 10 Vendors)' as Metric,
    CR10 as Value,
    PRINTF('%.2f%%', CR10) as Formatted_Value
FROM ConcentrationMetrics

UNION ALL

SELECT 
    'HHI (Herfindahl Index)' as Metric,
    HHI as Value,
    PRINTF('%.2f', HHI) as Formatted_Value
FROM ConcentrationMetrics

UNION ALL

SELECT 
    'Market Concentration' as Metric,
    CASE 
        WHEN HHI < 1000 THEN 1
        WHEN HHI < 1800 THEN 2
        ELSE 3
    END as Value,
    CASE 
        WHEN HHI < 1000 THEN 'Low'
        WHEN HHI < 1800 THEN 'Medium'
        ELSE 'High'
    END as Formatted_Value
FROM ConcentrationMetrics;

-- Vendor Dependency Risk Assessment
WITH VendorRisk AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalSalesDollars) * 100.0 / (SELECT SUM(TotalSalesDollars) FROM vendor_sales_summary) as MarketShare,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as AvgTurnover,
        SUM(FreightCost) * 100.0 / SUM(TotalPurchaseDollars) as FreightRatio,
        COUNT(DISTINCT Brand) as BrandDiversity
    FROM vendor_sales_summary
    GROUP BY VendorName
),
RiskScoring AS (
    SELECT 
        VendorName,
        TotalSales,
        MarketShare,
        ProfitMargin,
        AvgTurnover,
        FreightRatio,
        BrandDiversity,
        -- Risk score components
        (MarketShare * 50) as ConcentrationRisk,
        CASE WHEN ProfitMargin < 10 THEN 30 ELSE 0 END as MarginRisk,
        CASE WHEN AvgTurnover < 0.5 THEN 20 ELSE 0 END as TurnoverRisk,
        (FreightRatio * 10) as FreightRisk,
        CASE WHEN BrandDiversity < 3 THEN 20 ELSE 0 END as DiversityRisk
    FROM VendorRisk
)
SELECT 
    VendorName,
    TotalSales,
    MarketShare,
    ProfitMargin,
    AvgTurnover,
    FreightRatio,
    BrandDiversity,
    (ConcentrationRisk + MarginRisk + TurnoverRisk + FreightRisk + DiversityRisk) as TotalRiskScore,
    CASE 
        WHEN (ConcentrationRisk + MarginRisk + TurnoverRisk + FreightRisk + DiversityRisk) >= 70 THEN 'Critical'
        WHEN (ConcentrationRisk + MarginRisk + TurnoverRisk + FreightRisk + DiversityRisk) >= 50 THEN 'High'
        WHEN (ConcentrationRisk + MarginRisk + TurnoverRisk + FreightRisk + DiversityRisk) >= 30 THEN 'Medium'
        ELSE 'Low'
    END as RiskCategory,
    RANK() OVER (ORDER BY (ConcentrationRisk + MarginRisk + TurnoverRisk + FreightRisk + DiversityRisk) DESC) as RiskRank
FROM RiskScoring
ORDER BY TotalRiskScore DESC;

-- =====================================================
-- 7. TIME SERIES AND TREND ANALYSIS
-- =====================================================

-- Monthly Sales and Purchase Trends (from raw tables)
WITH MonthlySales AS (
    SELECT 
        strftime('%Y-%m', SalesDate) as Month,
        SUM(SalesDollars) as MonthlySales,
        SUM(SalesQuantity) as MonthlyUnits,
        COUNT(DISTINCT VendorNo) as ActiveVendors,
        COUNT(DISTINCT InventoryId) as UniqueProducts
    FROM sales
    WHERE SalesDate IS NOT NULL
    GROUP BY strftime('%Y-%m', SalesDate)
),
MonthlyPurchases AS (
    SELECT 
        strftime('%Y-%m', PODate) as Month,
        SUM(Dollars) as MonthlyPurchases,
        SUM(Quantity) as MonthlyUnits,
        COUNT(DISTINCT VendorNumber) as ActiveVendors,
        COUNT(DISTINCT PONumber) as PurchaseOrders
    FROM purchases
    WHERE PODate IS NOT NULL
    GROUP BY strftime('%Y-%m', PODate)
)
SELECT 
    COALESCE(ms.Month, mp.Month) as Month,
    COALESCE(ms.MonthlySales, 0) as MonthlySales,
    COALESCE(mp.MonthlyPurchases, 0) as MonthlyPurchases,
    COALESCE(ms.MonthlyUnits, 0) as MonthlySalesUnits,
    COALESCE(mp.MonthlyUnits, 0) as MonthlyPurchaseUnits,
    COALESCE(ms.ActiveVendors, 0) as ActiveSalesVendors,
    COALESCE(mp.ActiveVendors, 0) as ActivePurchaseVendors,
    CASE 
        WHEN LAG(COALESCE(ms.MonthlySales, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month)) = 0 THEN NULL
        ELSE ((COALESCE(ms.MonthlySales, 0) - LAG(COALESCE(ms.MonthlySales, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month))) / 
              LAG(COALESCE(ms.MonthlySales, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month))) * 100
    END as SalesGrowthPct,
    CASE 
        WHEN LAG(COALESCE(mp.MonthlyPurchases, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month)) = 0 THEN NULL
        ELSE ((COALESCE(mp.MonthlyPurchases, 0) - LAG(COALESCE(mp.MonthlyPurchases, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month))) / 
              LAG(COALESCE(mp.MonthlyPurchases, 0), 1) OVER (ORDER BY COALESCE(ms.Month, mp.Month))) * 100
    END as PurchaseGrowthPct
FROM MonthlySales ms
FULL OUTER JOIN MonthlyPurchases mp ON ms.Month = mp.Month
ORDER BY Month;

-- =====================================================
-- 8. PROFITABILITY ANALYSIS
-- =====================================================

-- Profit Margin Distribution Analysis
WITH ProfitBuckets AS (
    SELECT 
        VendorName,
        Description,
        (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars as ProfitMargin,
        CASE 
            WHEN (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars < 0 THEN 'Loss'
            WHEN (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars < 10 THEN 'Low Margin (0-10%)'
            WHEN (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars < 20 THEN 'Medium Margin (10-20%)'
            WHEN (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars < 30 THEN 'Good Margin (20-30%)'
            ELSE 'High Margin (30%+)'
        END as MarginCategory,
        TotalSalesDollars,
        TotalPurchaseDollars,
        (TotalSalesDollars - TotalPurchaseDollars) as GrossProfit
    FROM vendor_sales_summary
    WHERE TotalSalesDollars > 0
)
SELECT 
    MarginCategory,
    COUNT(*) as ProductCount,
    SUM(TotalSalesDollars) as TotalSales,
    SUM(TotalPurchaseDollars) as TotalPurchases,
    SUM(GrossProfit) as TotalProfit,
    AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as AvgMargin,
    SUM(TotalSalesDollars) * 100.0 / (SELECT SUM(TotalSalesDollars) FROM vendor_sales_summary) as SalesContribution
FROM ProfitBuckets
GROUP BY MarginCategory
ORDER BY 
    CASE MarginCategory
        WHEN 'Loss' THEN 1
        WHEN 'Low Margin (0-10%)' THEN 2
        WHEN 'Medium Margin (10-20%)' THEN 3
        WHEN 'Good Margin (20-30%)' THEN 4
        WHEN 'High Margin (30%+)' THEN 5
    END;

-- Most Profitable Vendors and Brands
WITH VendorProfitability AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalPurchaseDollars) as TotalPurchases,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        COUNT(*) as ProductCount
    FROM vendor_sales_summary
    WHERE TotalSalesDollars > 0
    GROUP BY VendorName
),
BrandProfitability AS (
    SELECT 
        Description,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalPurchaseDollars) as TotalPurchases,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        COUNT(DISTINCT VendorName) as VendorCount
    FROM vendor_sales_summary
    WHERE TotalSalesDollars > 0
    GROUP BY Description
)
SELECT 'Top 10 Most Profitable Vendors' as Category, 
       VendorName as Name, 
       TotalSales, 
       GrossProfit, 
       ProfitMargin, 
       ProductCount as Count
FROM VendorProfitability
ORDER BY GrossProfit DESC
LIMIT 10

UNION ALL

SELECT 'Top 10 Most Profitable Brands' as Category, 
       Description as Name, 
       TotalSales, 
       GrossProfit, 
       ProfitMargin, 
       VendorCount as Count
FROM BrandProfitability
ORDER BY GrossProfit DESC
LIMIT 10;

-- =====================================================
-- 9. COMPARATIVE ANALYSIS
-- =====================================================

-- High vs Low Performing Vendors Comparison
WITH VendorPerformance AS (
    SELECT 
        VendorName,
        SUM(TotalSalesDollars) as TotalSales,
        SUM(TotalSalesDollars - TotalPurchaseDollars) as GrossProfit,
        AVG((TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars) as ProfitMargin,
        AVG(TotalSalesQuantity * 1.0 / TotalPurchaseQuantity) as AvgTurnover,
        SUM(FreightCost) * 100.0 / SUM(TotalPurchaseDollars) as FreightRatio,
        COUNT(DISTINCT Brand) as BrandCount
    FROM vendor_sales_summary
    WHERE TotalSalesDollars > 0
    GROUP BY VendorName
),
PerformanceQuartiles AS (
    SELECT 
        VendorName,
        TotalSales,
        GrossProfit,
        ProfitMargin,
        AvgTurnover,
        FreightRatio,
        BrandCount,
        NTILE(2) OVER (ORDER BY TotalSales) as PerformanceGroup
    FROM VendorPerformance
)
SELECT 
    PerformanceGroup,
    COUNT(*) as VendorCount,
    AVG(TotalSales) as AvgSales,
    AVG(GrossProfit) as AvgProfit,
    AVG(ProfitMargin) as AvgMargin,
    AVG(AvgTurnover) as AvgTurnover,
    AVG(FreightRatio) as AvgFreightRatio,
    AVG(BrandCount) as AvgBrandCount
FROM PerformanceQuartiles
GROUP BY PerformanceGroup
ORDER BY PerformanceGroup;

-- =====================================================
-- 10. DATA QUALITY AND ANOMALY DETECTION
-- =====================================================

-- Data Quality Report
SELECT 
    'Total Records' as Metric,
    COUNT(*) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary

UNION ALL

SELECT 
    'Records with Zero Sales' as Metric,
    COUNT(*) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary
WHERE TotalSalesDollars = 0

UNION ALL

SELECT 
    'Records with Negative Profit' as Metric,
    COUNT(*) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary
WHERE TotalSalesDollars - TotalPurchaseDollars < 0

UNION ALL

SELECT 
    'Records with Zero Turnover' as Metric,
    COUNT(*) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary
WHERE TotalSalesQuantity = 0 AND TotalPurchaseQuantity > 0

UNION ALL

SELECT 
    'Records with Extreme Margins (>100%)' as Metric,
    COUNT(*) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary
WHERE (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars > 100

UNION ALL

SELECT 
    'Unique Vendors' as Metric,
    COUNT(DISTINCT VendorName) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary

UNION ALL

SELECT 
    'Unique Brands' as Metric,
    COUNT(DISTINCT Description) as Count,
    'vendor_sales_summary' as Table_Name
FROM vendor_sales_summary;

-- Anomaly Detection for Unusual Transactions
WITH AnomalyDetection AS (
    SELECT 
        VendorName,
        Description,
        TotalSalesDollars,
        TotalPurchaseDollars,
        (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars as ProfitMargin,
        TotalSalesQuantity * 1.0 / TotalPurchaseQuantity as TurnoverRatio,
        FreightCost,
        CASE 
            WHEN TotalSalesDollars = 0 AND TotalPurchaseDollars > 0 THEN 'No Sales Activity'
            WHEN (TotalSalesDollars - TotalPurchaseDollars) < 0 THEN 'Negative Profit'
            WHEN (TotalSalesDollars - TotalPurchaseDollars) * 100.0 / TotalSalesDollars > 100 THEN 'Extreme Margin'
            WHEN TotalSalesQuantity = 0 AND TotalPurchaseQuantity > 0 THEN 'No Sales Movement'
            WHEN TotalSalesQuantity * 1.0 / TotalPurchaseQuantity > 5 THEN 'Unusual High Turnover'
            WHEN FreightCost > TotalPurchaseDollars * 0.2 THEN 'High Freight Cost'
            ELSE 'Normal'
        END as AnomalyType
    FROM vendor_sales_summary
    WHERE TotalPurchaseDollars > 0
)
SELECT 
    AnomalyType,
    COUNT(*) as RecordCount,
    SUM(TotalSalesDollars) as TotalSales,
    SUM(TotalPurchaseDollars) as TotalPurchases,
    SUM(TotalSalesDollars - TotalPurchaseDollars) as TotalProfit
FROM AnomalyDetection
WHERE AnomalyType != 'Normal'
GROUP BY AnomalyType
ORDER BY RecordCount DESC;

-- =====================================================
-- END OF COMPREHENSIVE SQL QUERIES
-- =====================================================
