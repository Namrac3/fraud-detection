-- ===============================================
-- FRAUD DETECTION ANALYSIS USING SQL SERVER
-- Step-by-Step Guide with Complete Implementation
-- ===============================================

-- STEP 1: DATABASE SETUP AND TABLE CREATION
-- ==========================================

-- Create database for fraud detection
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'fraud_analytics')
BEGIN
    CREATE DATABASE fraud_analytics;
END
GO

USE fraud_analytics;
GO

-- Create transactions table (main table for analysis)
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='transactions' AND xtype='U')
BEGIN
    CREATE TABLE transactions (
        transaction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        card_id VARCHAR(20) NOT NULL,
        merchant_id VARCHAR(20) NOT NULL,
        merchant_category VARCHAR(50),
        transaction_amount DECIMAL(10,2) NOT NULL,
        transaction_date DATETIME NOT NULL,
        transaction_time TIME,
        location_city VARCHAR(100),
        location_state VARCHAR(50),
        location_country VARCHAR(50),
        is_fraud BIT DEFAULT 0,
        created_at DATETIME DEFAULT GETDATE()
    );
    
    CREATE INDEX idx_card_id ON transactions(card_id);
    CREATE INDEX idx_transaction_date ON transactions(transaction_date);
    CREATE INDEX idx_amount ON transactions(transaction_amount);
    CREATE INDEX idx_fraud ON transactions(is_fraud);
END
GO

-- Create cardholders table for customer information
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='cardholders' AND xtype='U')
BEGIN
    CREATE TABLE cardholders (
        card_id VARCHAR(20) PRIMARY KEY,
        cardholder_name VARCHAR(100),
        card_type VARCHAR(20),
        credit_limit DECIMAL(10,2),
        account_opened_date DATE,
        risk_score INT DEFAULT 50
    );
    
    CREATE INDEX idx_risk_score ON cardholders(risk_score);
END
GO

-- Create merchants table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='merchants' AND xtype='U')
BEGIN
    CREATE TABLE merchants (
        merchant_id VARCHAR(20) PRIMARY KEY,
        merchant_name VARCHAR(100),
        merchant_category VARCHAR(50),
        merchant_location VARCHAR(100),
        risk_level VARCHAR(10) DEFAULT 'LOW' CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH'))
    );
END
GO

-- ===============================================
-- STEP 2: SAMPLE DATA INSERTION
-- ===============================================

-- Insert sample cardholders
IF NOT EXISTS (SELECT 1 FROM cardholders WHERE card_id = 'CARD001')
BEGIN
    INSERT INTO cardholders VALUES
    ('CARD001', 'John Smith', 'VISA', 5000.00, '2020-01-15', 45),
    ('CARD002', 'Jane Doe', 'MASTERCARD', 3000.00, '2021-03-22', 60),
    ('CARD003', 'Bob Johnson', 'AMEX', 10000.00, '2019-08-10', 30),
    ('CARD004', 'Alice Brown', 'VISA', 2500.00, '2022-01-05', 75);
END
GO

-- Insert sample merchants
IF NOT EXISTS (SELECT 1 FROM merchants WHERE merchant_id = 'MERCH001')
BEGIN
    INSERT INTO merchants VALUES
    ('MERCH001', 'Amazon', 'E-commerce', 'Seattle, WA', 'LOW'),
    ('MERCH002', 'Gas Station XYZ', 'Fuel', 'Dallas, TX', 'MEDIUM'),
    ('MERCH003', 'Luxury Store ABC', 'Retail', 'New York, NY', 'HIGH'),
    ('MERCH004', 'ATM Withdrawal', 'Banking', 'Various', 'MEDIUM');
END
GO

-- Insert sample transactions (mix of normal and fraudulent)
IF NOT EXISTS (SELECT 1 FROM transactions WHERE card_id = 'CARD001')
BEGIN
    INSERT INTO transactions (card_id, merchant_id, merchant_category, transaction_amount, transaction_date, transaction_time, location_city, location_state, is_fraud) VALUES
    ('CARD001', 'MERCH001', 'E-commerce', 125.50, '2024-08-01 14:30:00', '14:30:00', 'Seattle', 'WA', 0),
    ('CARD001', 'MERCH002', 'Fuel', 45.00, '2024-08-01 18:15:00', '18:15:00', 'Dallas', 'TX', 0),
    ('CARD001', 'MERCH003', 'Retail', 2500.00, '2024-08-01 18:20:00', '18:20:00', 'New York', 'NY', 1), -- Suspicious: large amount + different location + short time gap
    ('CARD002', 'MERCH004', 'Banking', 500.00, '2024-08-02 02:30:00', '02:30:00', 'Miami', 'FL', 1), -- Suspicious: unusual time
    ('CARD002', 'MERCH001', 'E-commerce', 75.25, '2024-08-02 10:00:00', '10:00:00', 'Chicago', 'IL', 0),
    ('CARD003', 'MERCH003', 'Retail', 3500.00, '2024-08-03 15:45:00', '15:45:00', 'New York', 'NY', 0),
    ('CARD004', 'MERCH002', 'Fuel', 65.00, '2024-08-03 09:00:00', '09:00:00', 'Austin', 'TX', 0),
    ('CARD001', 'MERCH004', 'Banking', 1000.00, '2024-08-04 03:15:00', '03:15:00', 'Los Angeles', 'CA', 1); -- Suspicious: unusual time + large amount
END
GO

-- ===============================================
-- STEP 3: BASIC FRAUD DETECTION QUERIES
-- ===============================================

-- 3.1 Overview of fraudulent vs normal transactions
SELECT 
    is_fraud,
    COUNT(*) as transaction_count,
    AVG(transaction_amount) as avg_amount,
    SUM(transaction_amount) as total_amount,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions)), 2) as percentage
FROM transactions
GROUP BY is_fraud;

-- 3.2 Fraud detection by time patterns (unusual hours)
SELECT 
    DATEPART(HOUR, transaction_time) as hour_of_day,
    COUNT(*) as total_transactions,
    SUM(CAST(is_fraud AS INT)) as fraud_transactions,
    ROUND((SUM(CAST(is_fraud AS INT)) * 100.0 / COUNT(*)), 2) as fraud_percentage
FROM transactions
GROUP BY DATEPART(HOUR, transaction_time)
ORDER BY fraud_percentage DESC;

-- 3.3 Fraud detection by amount thresholds
SELECT 
    CASE 
        WHEN transaction_amount < 50 THEN 'Small (<$50)'
        WHEN transaction_amount BETWEEN 50 AND 500 THEN 'Medium ($50-$500)'
        WHEN transaction_amount BETWEEN 500 AND 1000 THEN 'Large ($500-$1000)'
        ELSE 'Very Large (>$1000)'
    END as amount_category,
    COUNT(*) as total_transactions,
    SUM(CAST(is_fraud AS INT)) as fraud_transactions,
    ROUND((SUM(CAST(is_fraud AS INT)) * 100.0 / COUNT(*)), 2) as fraud_percentage
FROM transactions
GROUP BY CASE 
    WHEN transaction_amount < 50 THEN 'Small (<$50)'
    WHEN transaction_amount BETWEEN 50 AND 500 THEN 'Medium ($50-$500)'
    WHEN transaction_amount BETWEEN 500 AND 1000 THEN 'Large ($500-$1000)'
    ELSE 'Very Large (>$1000)'
END
ORDER BY fraud_percentage DESC;

-- ===============================================
-- STEP 4: ADVANCED FRAUD DETECTION PATTERNS
-- ===============================================

-- 4.1 Detect velocity fraud (multiple transactions in short time)
WITH transaction_velocity AS (
    SELECT 
        t1.card_id,
        t1.transaction_id,
        t1.transaction_amount,
        t1.transaction_date,
        COUNT(t2.transaction_id) as transactions_in_hour
    FROM transactions t1
    LEFT JOIN transactions t2 ON t1.card_id = t2.card_id
        AND t2.transaction_date BETWEEN DATEADD(HOUR, -1, t1.transaction_date) AND t1.transaction_date
        AND t2.transaction_id != t1.transaction_id
    GROUP BY t1.card_id, t1.transaction_id, t1.transaction_amount, t1.transaction_date
)
SELECT 
    tv.*,
    CASE WHEN transactions_in_hour >= 3 THEN 'HIGH_VELOCITY_RISK' ELSE 'NORMAL' END as velocity_risk
FROM transaction_velocity tv
WHERE transactions_in_hour >= 2
ORDER BY transactions_in_hour DESC;

-- 4.2 Geographic anomaly detection (distant locations in short time)
WITH location_changes AS (
    SELECT 
        t1.card_id,
        t1.transaction_id as current_transaction,
        t1.location_state as current_location,
        t1.transaction_date as current_transaction_date,
        LAG(t1.location_state) OVER (PARTITION BY t1.card_id ORDER BY t1.transaction_date) as previous_location,
        LAG(t1.transaction_date) OVER (PARTITION BY t1.card_id ORDER BY t1.transaction_date) as previous_transaction_date,
        DATEDIFF(MINUTE, LAG(t1.transaction_date) OVER (PARTITION BY t1.card_id ORDER BY t1.transaction_date), t1.transaction_date) as time_diff_minutes
    FROM transactions t1
)
SELECT 
    *,
    CASE 
        WHEN current_location != previous_location AND time_diff_minutes < 240 THEN 'LOCATION_ANOMALY'
        ELSE 'NORMAL'
    END as location_risk
FROM location_changes
WHERE current_location != previous_location AND time_diff_minutes IS NOT NULL
ORDER BY time_diff_minutes;

-- 4.3 Amount pattern analysis (unusually high amounts)
WITH amount_patterns AS (
    SELECT 
        card_id,
        AVG(transaction_amount) as avg_amount,
        STDEV(transaction_amount) as std_amount,
        MAX(transaction_amount) as max_amount,
        MIN(transaction_amount) as min_amount
    FROM transactions
    WHERE is_fraud = 0  -- Calculate baseline from non-fraudulent transactions
    GROUP BY card_id
)
SELECT 
    t.transaction_id,
    t.card_id,
    t.transaction_amount,
    ap.avg_amount,
    ap.std_amount,
    CASE 
        WHEN ap.std_amount > 0 THEN ROUND((t.transaction_amount - ap.avg_amount) / ap.std_amount, 2)
        ELSE 0
    END as z_score,
    CASE 
        WHEN ap.std_amount > 0 AND ABS((t.transaction_amount - ap.avg_amount) / ap.std_amount) > 2 THEN 'AMOUNT_ANOMALY'
        ELSE 'NORMAL'
    END as amount_risk,
    t.is_fraud as actual_fraud
FROM transactions t
JOIN amount_patterns ap ON t.card_id = ap.card_id
WHERE ap.std_amount > 0
ORDER BY CASE WHEN ap.std_amount > 0 THEN ABS((t.transaction_amount - ap.avg_amount) / ap.std_amount) ELSE 0 END DESC;

-- ===============================================
-- STEP 5: MERCHANT AND CATEGORY ANALYSIS
-- ===============================================

-- 5.1 High-risk merchants analysis
SELECT 
    m.merchant_name,
    m.merchant_category,
    m.risk_level,
    COUNT(t.transaction_id) as total_transactions,
    SUM(CAST(t.is_fraud AS INT)) as fraud_transactions,
    CASE 
        WHEN COUNT(t.transaction_id) > 0 THEN ROUND((SUM(CAST(t.is_fraud AS INT)) * 100.0 / COUNT(t.transaction_id)), 2)
        ELSE 0
    END as fraud_rate,
    AVG(t.transaction_amount) as avg_transaction_amount
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.merchant_category, m.risk_level
HAVING COUNT(t.transaction_id) > 0
ORDER BY fraud_rate DESC, total_transactions DESC;

-- 5.2 Category-wise fraud analysis
SELECT 
    merchant_category,
    COUNT(*) as total_transactions,
    SUM(CAST(is_fraud AS INT)) as fraud_transactions,
    ROUND((SUM(CAST(is_fraud AS INT)) * 100.0 / COUNT(*)), 2) as fraud_percentage,
    AVG(transaction_amount) as avg_amount,
    MAX(transaction_amount) as max_amount
FROM transactions
GROUP BY merchant_category
ORDER BY fraud_percentage DESC;

-- ===============================================
-- STEP 6: CUSTOMER RISK PROFILING
-- ===============================================

-- 6.1 Customer risk scoring based on transaction patterns
WITH customer_metrics AS (
    SELECT 
        t.card_id,
        COUNT(*) as total_transactions,
        SUM(CAST(t.is_fraud AS INT)) as fraud_transactions,
        AVG(t.transaction_amount) as avg_amount,
        MAX(t.transaction_amount) as max_amount,
        STDEV(t.transaction_amount) as amount_variance,
        COUNT(DISTINCT t.location_state) as unique_locations,
        COUNT(DISTINCT t.merchant_category) as unique_categories,
        -- Count unusual time transactions (between 11 PM and 6 AM)
        SUM(CASE WHEN DATEPART(HOUR, t.transaction_time) >= 23 OR DATEPART(HOUR, t.transaction_time) <= 6 THEN 1 ELSE 0 END) as unusual_time_transactions
    FROM transactions t
    GROUP BY t.card_id
)
SELECT 
    cm.*,
    c.cardholder_name,
    c.credit_limit,
    c.risk_score as current_risk_score,
    CASE 
        WHEN cm.total_transactions > 0 THEN ROUND((cm.fraud_transactions * 100.0 / cm.total_transactions), 2)
        ELSE 0
    END as fraud_rate,
    -- Calculate new risk score based on patterns
    CASE 
        WHEN cm.fraud_transactions > 0 THEN 90
        WHEN cm.unusual_time_transactions > cm.total_transactions * 0.3 THEN 75
        WHEN cm.unique_locations > 5 THEN 70
        WHEN cm.max_amount > c.credit_limit * 0.8 THEN 65
        ELSE 40
    END as calculated_risk_score
FROM customer_metrics cm
JOIN cardholders c ON cm.card_id = c.card_id
ORDER BY calculated_risk_score DESC;

-- ===============================================
-- STEP 7: REAL-TIME FRAUD SCORING FUNCTION
-- ===============================================
GO

-- Create a stored procedure for real-time fraud scoring
CREATE OR ALTER PROCEDURE CalculateFraudScore
    @p_card_id VARCHAR(20),
    @p_transaction_amount DECIMAL(10,2),
    @p_merchant_id VARCHAR(20),
    @p_location_state VARCHAR(50),
    @p_transaction_time TIME,
    @fraud_score INT OUTPUT
AS
BEGIN
    DECLARE @v_avg_amount DECIMAL(10,2);
    DECLARE @v_last_location VARCHAR(50);
    DECLARE @v_last_transaction_time DATETIME;
    DECLARE @v_recent_transactions INT;
    DECLARE @v_merchant_risk VARCHAR(10);
    DECLARE @v_time_score INT = 0;
    DECLARE @v_amount_score INT = 0;
    DECLARE @v_location_score INT = 0;
    DECLARE @v_velocity_score INT = 0;
    DECLARE @v_merchant_score INT = 0;
    
    -- Get user's average transaction amount
    SELECT @v_avg_amount = AVG(transaction_amount)
    FROM transactions 
    WHERE card_id = @p_card_id AND is_fraud = 0;
    
    -- Get last transaction location and time
    SELECT TOP 1 @v_last_location = location_state, @v_last_transaction_time = transaction_date
    FROM transactions 
    WHERE card_id = @p_card_id 
    ORDER BY transaction_date DESC;
    
    -- Count recent transactions (last hour)
    SELECT @v_recent_transactions = COUNT(*)
    FROM transactions 
    WHERE card_id = @p_card_id 
    AND transaction_date >= DATEADD(HOUR, -1, GETDATE());
    
    -- Get merchant risk level
    SELECT @v_merchant_risk = risk_level
    FROM merchants 
    WHERE merchant_id = @p_merchant_id;
    
    -- Time-based scoring (unusual hours = higher risk)
    IF DATEPART(HOUR, @p_transaction_time) >= 23 OR DATEPART(HOUR, @p_transaction_time) <= 6
        SET @v_time_score = 25;
    ELSE
        SET @v_time_score = 5;
    
    -- Amount-based scoring
    IF @p_transaction_amount > @v_avg_amount * 3
        SET @v_amount_score = 30;
    ELSE IF @p_transaction_amount > @v_avg_amount * 2
        SET @v_amount_score = 20;
    ELSE
        SET @v_amount_score = 5;
    
    -- Location-based scoring
    IF @v_last_location IS NOT NULL AND @v_last_location != @p_location_state
    BEGIN
        IF DATEDIFF(HOUR, @v_last_transaction_time, GETDATE()) < 4
            SET @v_location_score = 25;
        ELSE
            SET @v_location_score = 10;
    END
    ELSE
        SET @v_location_score = 0;
    
    -- Velocity scoring
    IF @v_recent_transactions >= 3
        SET @v_velocity_score = 30;
    ELSE IF @v_recent_transactions >= 2
        SET @v_velocity_score = 15;
    ELSE
        SET @v_velocity_score = 0;
    
    -- Merchant scoring
    IF @v_merchant_risk = 'HIGH'
        SET @v_merchant_score = 20;
    ELSE IF @v_merchant_risk = 'MEDIUM'
        SET @v_merchant_score = 10;
    ELSE
        SET @v_merchant_score = 0;
    
    -- Calculate final fraud score
    SET @fraud_score = @v_time_score + @v_amount_score + @v_location_score + @v_velocity_score + @v_merchant_score;
    
    -- Cap the score at 100
    IF @fraud_score > 100
        SET @fraud_score = 100;
    
END
GO

-- ===============================================
-- STEP 8: FRAUD DETECTION DASHBOARD QUERIES
-- ===============================================

-- 8.1 Daily fraud summary
SELECT 
    CAST(transaction_date AS DATE) as transaction_date,
    COUNT(*) as total_transactions,
    SUM(CAST(is_fraud AS INT)) as fraud_transactions,
    ROUND((SUM(CAST(is_fraud AS INT)) * 100.0 / COUNT(*)), 2) as fraud_percentage,
    SUM(transaction_amount) as total_amount,
    SUM(CASE WHEN is_fraud = 1 THEN transaction_amount ELSE 0 END) as fraud_amount
FROM transactions
WHERE transaction_date >= DATEADD(DAY, -7, GETDATE())
GROUP BY CAST(transaction_date AS DATE)
ORDER BY transaction_date DESC;

-- 8.2 Top risky transactions (for investigation)
WITH transaction_risks AS (
    SELECT 
        t.transaction_id,
        t.card_id,
        c.cardholder_name,
        t.merchant_id,
        m.merchant_name,
        t.transaction_amount,
        t.transaction_date,
        t.location_city,
        t.location_state,
        t.is_fraud,
        -- Calculate risk factors
        CASE WHEN DATEPART(HOUR, t.transaction_time) >= 23 OR DATEPART(HOUR, t.transaction_time) <= 6 THEN 'Unusual Time' ELSE '' END as time_risk,
        CASE WHEN t.transaction_amount > 1000 THEN 'High Amount' ELSE '' END as amount_risk,
        -- Risk score calculation
        (CASE WHEN DATEPART(HOUR, t.transaction_time) >= 23 OR DATEPART(HOUR, t.transaction_time) <= 6 THEN 1 ELSE 0 END +
         CASE WHEN t.transaction_amount > 1000 THEN 1 ELSE 0 END) as risk_score
    FROM transactions t
    JOIN cardholders c ON t.card_id = c.card_id
    JOIN merchants m ON t.merchant_id = m.merchant_id
    WHERE t.transaction_date >= DATEADD(DAY, -1, GETDATE())
)
SELECT *
FROM transaction_risks
ORDER BY risk_score DESC, transaction_amount DESC;

-- ===============================================
-- STEP 9: PERFORMANCE MONITORING QUERIES
-- ===============================================

-- 9.1 Model performance metrics
WITH fraud_predictions AS (
    SELECT 
        transaction_id,
        is_fraud as actual_fraud,
        -- Predict fraud based on simple rules (can be replaced with ML model scores)
        CASE 
            WHEN (DATEPART(HOUR, transaction_time) >= 23 OR DATEPART(HOUR, transaction_time) <= 6) 
                 AND transaction_amount > 1000 THEN 1
            WHEN transaction_amount > 2000 THEN 1
            ELSE 0
        END as predicted_fraud
    FROM transactions
)
SELECT 
    -- True Positives: Correctly identified fraud
    SUM(CASE WHEN actual_fraud = 1 AND predicted_fraud = 1 THEN 1 ELSE 0 END) as true_positives,
    -- False Positives: Incorrectly flagged as fraud
    SUM(CASE WHEN actual_fraud = 0 AND predicted_fraud = 1 THEN 1 ELSE 0 END) as false_positives,
    -- True Negatives: Correctly identified as normal
    SUM(CASE WHEN actual_fraud = 0 AND predicted_fraud = 0 THEN 1 ELSE 0 END) as true_negatives,
    -- False Negatives: Missed fraud
    SUM(CASE WHEN actual_fraud = 1 AND predicted_fraud = 0 THEN 1 ELSE 0 END) as false_negatives,
    -- Calculate precision, recall, and accuracy
    CASE 
        WHEN SUM(CASE WHEN predicted_fraud = 1 THEN 1 ELSE 0 END) > 0 THEN
            ROUND(SUM(CASE WHEN actual_fraud = 1 AND predicted_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
                  SUM(CASE WHEN predicted_fraud = 1 THEN 1 ELSE 0 END), 2)
        ELSE 0
    END as precision_percentage,
    CASE 
        WHEN SUM(CASE WHEN actual_fraud = 1 THEN 1 ELSE 0 END) > 0 THEN
            ROUND(SUM(CASE WHEN actual_fraud = 1 AND predicted_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
                  SUM(CASE WHEN actual_fraud = 1 THEN 1 ELSE 0 END), 2)
        ELSE 0
    END as recall_percentage,
    ROUND((SUM(CASE WHEN actual_fraud = predicted_fraud THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) as accuracy_percentage
FROM fraud_predictions;

-- ===============================================
-- STEP 10: AUTOMATED ALERT SYSTEM
-- ===============================================

-- Create alerts table for tracking suspicious activities
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='fraud_alerts' AND xtype='U')
BEGIN
    CREATE TABLE fraud_alerts (
        alert_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        transaction_id BIGINT,
        card_id VARCHAR(20),
        alert_type VARCHAR(50),
        alert_message TEXT,
        risk_score INT,
        alert_date DATETIME DEFAULT GETDATE(),
        status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'FALSE_POSITIVE')),
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
    );
    
    CREATE INDEX idx_status ON fraud_alerts(status);
    CREATE INDEX idx_risk_score ON fraud_alerts(risk_score);
END
GO

GO

CREATE OR ALTER PROCEDURE GenerateFraudAlerts
AS
BEGIN
    -- Insert alerts for high-risk transactions
    INSERT INTO fraud_alerts (transaction_id, card_id, alert_type, alert_message, risk_score)
    SELECT 
        t.transaction_id,
        t.card_id,
        'HIGH_AMOUNT' as alert_type,
        CONCAT('Transaction amount $', CAST(t.transaction_amount AS VARCHAR(20)), ' is significantly higher than user average') as alert_message,
        80 as risk_score
    FROM transactions t
    WHERE t.transaction_date >= DATEADD(DAY, -1, GETDATE())
    AND t.transaction_amount > (
        SELECT AVG(t2.transaction_amount) * 3 
        FROM transactions t2 
        WHERE t2.card_id = t.card_id 
        AND t2.is_fraud = 0
    )
    AND NOT EXISTS (
        SELECT 1 FROM fraud_alerts fa 
        WHERE fa.transaction_id = t.transaction_id
    );
    
    -- Insert alerts for unusual time transactions
    INSERT INTO fraud_alerts (transaction_id, card_id, alert_type, alert_message, risk_score)
    SELECT 
        transaction_id,
        card_id,
        'UNUSUAL_TIME' as alert_type,
        CONCAT('Transaction occurred at unusual time: ', FORMAT(transaction_time, 'HH:mm')) as alert_message,
        60 as risk_score
    FROM transactions
    WHERE transaction_date >= DATEADD(DAY, -1, GETDATE())
    AND (DATEPART(HOUR, transaction_time) >= 23 OR DATEPART(HOUR, transaction_time) <= 6)
    AND transaction_amount > 500
    AND NOT EXISTS (
        SELECT 1 FROM fraud_alerts fa 
        WHERE fa.transaction_id = transactions.transaction_id
    );
    
END
GO

-- ===============================================
-- EXAMPLE USAGE AND TESTING
-- ===============================================

-- Test the fraud scoring procedure
DECLARE @score INT;
EXEC CalculateFraudScore 'CARD001', 2000.00, 'MERCH003', 'NY', '02:30:00', @score OUTPUT;
SELECT @score as fraud_score;

-- Generate alerts for recent transactions
EXEC GenerateFraudAlerts;

-- View current alerts
SELECT 
    fa.alert_id,
    fa.card_id,
    c.cardholder_name,
    fa.alert_type,
    fa.alert_message,
    fa.risk_score,
    fa.alert_date,
    fa.status,
    t.transaction_amount,
    t.merchant_id
FROM fraud_alerts fa
JOIN cardholders c ON fa.card_id = c.card_id
JOIN transactions t ON fa.transaction_id = t.transaction_id
WHERE fa.status = 'OPEN'
ORDER BY fa.risk_score DESC, fa.alert_date DESC;
GO

-- ===============================================
-- STEP 11: OPTIMIZATION AND INDEXES
-- ===============================================

-- Add additional indexes for better performance (with existence checks)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_transaction_card_date' AND object_id = OBJECT_ID('transactions'))
    CREATE INDEX idx_transaction_card_date ON transactions(card_id, transaction_date);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_transaction_amount_date' AND object_id = OBJECT_ID('transactions'))
    CREATE INDEX idx_transaction_amount_date ON transactions(transaction_amount, transaction_date);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_fraud_date' AND object_id = OBJECT_ID('transactions'))
    CREATE INDEX idx_fraud_date ON transactions(is_fraud, transaction_date);
GO

-- Create view for easy fraud analysis
CREATE OR ALTER VIEW fraud_analysis_view AS
SELECT 
    t.transaction_id,
    t.card_id,
    c.cardholder_name,
    t.transaction_amount,
    t.transaction_date,
    t.merchant_id,
    m.merchant_name,
    m.merchant_category,
    t.location_city,
    t.location_state,
    t.is_fraud,
    -- Risk indicators
    CASE WHEN DATEPART(HOUR, t.transaction_time) >= 23 OR DATEPART(HOUR, t.transaction_time) <= 6 THEN 1 ELSE 0 END as unusual_time_flag,
    CASE WHEN t.transaction_amount > 1000 THEN 1 ELSE 0 END as high_amount_flag,
    -- Days since account opened
    DATEDIFF(DAY, c.account_opened_date, t.transaction_date) as days_since_account_opened
FROM transactions t
JOIN cardholders c ON t.card_id = c.card_id
JOIN merchants m ON t.merchant_id = m.merchant_id;
GO

-- ===============================================
-- FINAL NOTES AND RECOMMENDATIONS
-- ===============================================

/*
IMPLEMENTATION RECOMMENDATIONS FOR SQL SERVER:

1. DATA COLLECTION:
    - Ensure you have historical transaction data with known fraud labels
    - Include as many relevant features as possible (time, location, amount, merchant, etc.)
    - Regular data quality checks and cleaning

2. MODEL TUNING:
    - Adjust thresholds based on your business requirements
    - Consider false positive vs false negative costs
    - Regularly retrain and update rules based on new fraud patterns

3. REAL-TIME PROCESSING:
    - Implement this system with real-time transaction processing
    - Set up automated alerts and notifications
    - Create dashboards for fraud analysts using SQL Server Reporting Services

4. PERFORMANCE OPTIMIZATION:
    - Monitor query performance and add indexes as needed
    - Consider partitioning large transaction tables by date
    - Use appropriate data archiving strategies
    - Utilize SQL Server's built-in performance monitoring tools

5. SECURITY:
    - Implement proper access controls using SQL Server security features
    - Enable Transparent Data Encryption (TDE) for sensitive data
    - Audit log all fraud investigation activities using SQL Server Audit

6. COMPLIANCE:
    - Ensure compliance with relevant regulations (PCI DSS, etc.)
    - Implement proper data retention policies
    - Document all fraud detection procedures

7. SQL SERVER SPECIFIC FEATURES:
    - Consider using SQL Server Machine Learning Services for advanced analytics
    - Utilize SQL Server Integration Services (SSIS) for data processing
    - Implement real-time analytics with SQL Server 2019+ features
*/
