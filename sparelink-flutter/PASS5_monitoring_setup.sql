-- =====================================================
-- PASS 5: AUTOMATED MONITORING SETUP
-- Run this in Supabase SQL Editor
-- =====================================================
-- Purpose: Set up database-level monitoring for:
-- 1. High error rates
-- 2. Database latency
-- 3. Failed transactions
-- 4. Rate limit violations
-- =====================================================

-- =====================================================
-- 1. ERROR LOGGING TABLE
-- =====================================================
-- Track application errors for monitoring dashboards

CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  error_code TEXT NOT NULL,
  error_message TEXT NOT NULL,
  error_type TEXT CHECK (error_type IN ('database', 'api', 'payment', 'auth', 'validation', 'unknown')),
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  endpoint TEXT,
  request_payload JSONB,
  stack_trace TEXT,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for monitoring queries
CREATE INDEX IF NOT EXISTS idx_error_logs_created 
  ON error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_severity 
  ON error_logs(severity, created_at DESC) 
  WHERE resolved = FALSE;
CREATE INDEX IF NOT EXISTS idx_error_logs_type 
  ON error_logs(error_type, created_at DESC);

-- =====================================================
-- 2. PERFORMANCE METRICS TABLE
-- =====================================================
-- Track query performance and latency

CREATE TABLE IF NOT EXISTS performance_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  metric_unit TEXT DEFAULT 'ms',
  endpoint TEXT,
  query_type TEXT CHECK (query_type IN ('select', 'insert', 'update', 'delete', 'rpc', 'realtime')),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata JSONB,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partition by time for efficient querying
CREATE INDEX IF NOT EXISTS idx_performance_metrics_recorded 
  ON performance_metrics(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name 
  ON performance_metrics(metric_name, recorded_at DESC);

-- =====================================================
-- 3. HEALTH CHECK VIEW
-- =====================================================
-- Real-time health status for monitoring dashboards

CREATE OR REPLACE VIEW system_health_status AS
SELECT 
  -- Error rates (last hour)
  (SELECT COUNT(*) FROM error_logs WHERE created_at > NOW() - INTERVAL '1 hour') as errors_last_hour,
  (SELECT COUNT(*) FROM error_logs WHERE created_at > NOW() - INTERVAL '1 hour' AND severity = 'critical') as critical_errors_last_hour,
  
  -- Active users (last 15 minutes based on activity)
  (SELECT COUNT(DISTINCT mechanic_id) FROM part_requests WHERE created_at > NOW() - INTERVAL '15 minutes') as active_mechanics,
  (SELECT COUNT(DISTINCT owner_id) FROM shops s JOIN offers o ON s.id = o.shop_id WHERE o.created_at > NOW() - INTERVAL '15 minutes') as active_shops,
  
  -- Transaction volume (last hour)
  (SELECT COUNT(*) FROM orders WHERE created_at > NOW() - INTERVAL '1 hour') as orders_last_hour,
  (SELECT COUNT(*) FROM offers WHERE created_at > NOW() - INTERVAL '1 hour') as offers_last_hour,
  (SELECT COUNT(*) FROM part_requests WHERE created_at > NOW() - INTERVAL '1 hour') as requests_last_hour,
  
  -- Payment status
  (SELECT COUNT(*) FROM payments WHERE status = 'pending' AND created_at > NOW() - INTERVAL '1 hour') as pending_payments,
  (SELECT COUNT(*) FROM payments WHERE status = 'failed' AND created_at > NOW() - INTERVAL '1 hour') as failed_payments_last_hour,
  
  -- Database health
  (SELECT COUNT(*) FROM rate_limit_log WHERE created_at > NOW() - INTERVAL '5 minutes') as rate_limit_hits_5min,
  
  -- Timestamp
  NOW() as checked_at;

-- =====================================================
-- 4. ALERT THRESHOLDS TABLE
-- =====================================================
-- Configure alerting thresholds

CREATE TABLE IF NOT EXISTS alert_thresholds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  metric_name TEXT UNIQUE NOT NULL,
  warning_threshold NUMERIC NOT NULL,
  critical_threshold NUMERIC NOT NULL,
  alert_channel TEXT CHECK (alert_channel IN ('email', 'slack', 'webhook', 'all')) DEFAULT 'all',
  enabled BOOLEAN DEFAULT TRUE,
  cooldown_minutes INT DEFAULT 15,
  last_alert_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default thresholds
INSERT INTO alert_thresholds (metric_name, warning_threshold, critical_threshold, alert_channel) VALUES
  ('errors_per_hour', 10, 50, 'all'),
  ('critical_errors_per_hour', 1, 5, 'all'),
  ('failed_payments_per_hour', 3, 10, 'all'),
  ('avg_response_time_ms', 500, 2000, 'webhook'),
  ('rate_limit_violations_per_5min', 50, 200, 'webhook'),
  ('pending_payments_stuck', 10, 50, 'email')
ON CONFLICT (metric_name) DO NOTHING;

-- =====================================================
-- 5. ALERT HISTORY TABLE
-- =====================================================
-- Track when alerts were triggered

CREATE TABLE IF NOT EXISTS alert_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_type TEXT NOT NULL,
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  threshold_value NUMERIC NOT NULL,
  severity TEXT CHECK (severity IN ('warning', 'critical')) NOT NULL,
  message TEXT NOT NULL,
  acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_at TIMESTAMPTZ,
  acknowledged_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alert_history_created 
  ON alert_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alert_history_unacknowledged 
  ON alert_history(created_at DESC) 
  WHERE acknowledged = FALSE;

-- =====================================================
-- 6. CHECK ALERTS FUNCTION
-- =====================================================
-- Function to check all thresholds and create alerts

CREATE OR REPLACE FUNCTION check_and_create_alerts()
RETURNS TABLE (
  alert_created BOOLEAN,
  metric_name TEXT,
  current_value NUMERIC,
  severity TEXT,
  message TEXT
) AS $$
DECLARE
  health RECORD;
  threshold RECORD;
  v_alert_created BOOLEAN;
  v_severity TEXT;
  v_message TEXT;
BEGIN
  -- Get current health status
  SELECT * INTO health FROM system_health_status LIMIT 1;
  
  -- Check each threshold
  FOR threshold IN SELECT * FROM alert_thresholds WHERE enabled = TRUE
  LOOP
    v_alert_created := FALSE;
    v_severity := NULL;
    v_message := NULL;
    
    -- Check errors_per_hour
    IF threshold.metric_name = 'errors_per_hour' THEN
      IF health.errors_last_hour >= threshold.critical_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'critical';
        v_message := format('CRITICAL: %s errors in the last hour (threshold: %s)', health.errors_last_hour, threshold.critical_threshold);
      ELSIF health.errors_last_hour >= threshold.warning_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'warning';
        v_message := format('WARNING: %s errors in the last hour (threshold: %s)', health.errors_last_hour, threshold.warning_threshold);
      END IF;
      
      IF v_alert_created AND (threshold.last_alert_at IS NULL OR threshold.last_alert_at < NOW() - (threshold.cooldown_minutes || ' minutes')::INTERVAL) THEN
        INSERT INTO alert_history (alert_type, metric_name, metric_value, threshold_value, severity, message)
        VALUES ('threshold_breach', threshold.metric_name, health.errors_last_hour, 
                CASE WHEN v_severity = 'critical' THEN threshold.critical_threshold ELSE threshold.warning_threshold END,
                v_severity, v_message);
        UPDATE alert_thresholds SET last_alert_at = NOW() WHERE id = threshold.id;
        
        RETURN QUERY SELECT TRUE, threshold.metric_name, health.errors_last_hour::NUMERIC, v_severity, v_message;
      END IF;
    END IF;
    
    -- Check critical_errors_per_hour
    IF threshold.metric_name = 'critical_errors_per_hour' THEN
      IF health.critical_errors_last_hour >= threshold.critical_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'critical';
        v_message := format('CRITICAL: %s critical errors in the last hour!', health.critical_errors_last_hour);
      ELSIF health.critical_errors_last_hour >= threshold.warning_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'warning';
        v_message := format('WARNING: %s critical errors in the last hour', health.critical_errors_last_hour);
      END IF;
      
      IF v_alert_created AND (threshold.last_alert_at IS NULL OR threshold.last_alert_at < NOW() - (threshold.cooldown_minutes || ' minutes')::INTERVAL) THEN
        INSERT INTO alert_history (alert_type, metric_name, metric_value, threshold_value, severity, message)
        VALUES ('threshold_breach', threshold.metric_name, health.critical_errors_last_hour,
                CASE WHEN v_severity = 'critical' THEN threshold.critical_threshold ELSE threshold.warning_threshold END,
                v_severity, v_message);
        UPDATE alert_thresholds SET last_alert_at = NOW() WHERE id = threshold.id;
        
        RETURN QUERY SELECT TRUE, threshold.metric_name, health.critical_errors_last_hour::NUMERIC, v_severity, v_message;
      END IF;
    END IF;
    
    -- Check failed_payments_per_hour
    IF threshold.metric_name = 'failed_payments_per_hour' THEN
      IF health.failed_payments_last_hour >= threshold.critical_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'critical';
        v_message := format('CRITICAL: %s failed payments in the last hour!', health.failed_payments_last_hour);
      ELSIF health.failed_payments_last_hour >= threshold.warning_threshold THEN
        v_alert_created := TRUE;
        v_severity := 'warning';
        v_message := format('WARNING: %s failed payments in the last hour', health.failed_payments_last_hour);
      END IF;
      
      IF v_alert_created AND (threshold.last_alert_at IS NULL OR threshold.last_alert_at < NOW() - (threshold.cooldown_minutes || ' minutes')::INTERVAL) THEN
        INSERT INTO alert_history (alert_type, metric_name, metric_value, threshold_value, severity, message)
        VALUES ('threshold_breach', threshold.metric_name, health.failed_payments_last_hour,
                CASE WHEN v_severity = 'critical' THEN threshold.critical_threshold ELSE threshold.warning_threshold END,
                v_severity, v_message);
        UPDATE alert_thresholds SET last_alert_at = NOW() WHERE id = threshold.id;
        
        RETURN QUERY SELECT TRUE, threshold.metric_name, health.failed_payments_last_hour::NUMERIC, v_severity, v_message;
      END IF;
    END IF;
    
  END LOOP;
  
  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. LOG ERROR FUNCTION (for API calls)
-- =====================================================
-- Function to log errors from the application

CREATE OR REPLACE FUNCTION log_error(
  p_error_code TEXT,
  p_error_message TEXT,
  p_error_type TEXT DEFAULT 'unknown',
  p_severity TEXT DEFAULT 'medium',
  p_endpoint TEXT DEFAULT NULL,
  p_request_payload JSONB DEFAULT NULL,
  p_stack_trace TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_error_id UUID;
BEGIN
  INSERT INTO error_logs (
    error_code, 
    error_message, 
    error_type, 
    severity, 
    user_id,
    endpoint, 
    request_payload, 
    stack_trace
  ) VALUES (
    p_error_code,
    p_error_message,
    p_error_type,
    p_severity,
    auth.uid(),
    p_endpoint,
    p_request_payload,
    p_stack_trace
  ) RETURNING id INTO v_error_id;
  
  RETURN v_error_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 8. LOG PERFORMANCE METRIC FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION log_performance_metric(
  p_metric_name TEXT,
  p_metric_value NUMERIC,
  p_metric_unit TEXT DEFAULT 'ms',
  p_endpoint TEXT DEFAULT NULL,
  p_query_type TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_metric_id UUID;
BEGIN
  INSERT INTO performance_metrics (
    metric_name,
    metric_value,
    metric_unit,
    endpoint,
    query_type,
    user_id,
    metadata
  ) VALUES (
    p_metric_name,
    p_metric_value,
    p_metric_unit,
    p_endpoint,
    p_query_type,
    auth.uid(),
    p_metadata
  ) RETURNING id INTO v_metric_id;
  
  RETURN v_metric_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 9. DAILY METRICS AGGREGATION
-- =====================================================
-- Aggregated daily metrics for dashboards

CREATE TABLE IF NOT EXISTS daily_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  metric_date DATE NOT NULL,
  total_requests INT DEFAULT 0,
  total_offers INT DEFAULT 0,
  total_orders INT DEFAULT 0,
  total_revenue_cents BIGINT DEFAULT 0,
  total_errors INT DEFAULT 0,
  avg_response_time_ms NUMERIC,
  active_mechanics INT DEFAULT 0,
  active_shops INT DEFAULT 0,
  new_users INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (metric_date)
);

-- Function to aggregate daily metrics
CREATE OR REPLACE FUNCTION aggregate_daily_metrics(p_date DATE DEFAULT CURRENT_DATE - 1)
RETURNS void AS $$
BEGIN
  INSERT INTO daily_metrics (
    metric_date,
    total_requests,
    total_offers,
    total_orders,
    total_revenue_cents,
    total_errors,
    active_mechanics,
    active_shops
  )
  SELECT
    p_date,
    (SELECT COUNT(*) FROM part_requests WHERE DATE(created_at) = p_date),
    (SELECT COUNT(*) FROM offers WHERE DATE(created_at) = p_date),
    (SELECT COUNT(*) FROM orders WHERE DATE(created_at) = p_date),
    (SELECT COALESCE(SUM(total_cents), 0) FROM orders WHERE DATE(created_at) = p_date AND status = 'delivered'),
    (SELECT COUNT(*) FROM error_logs WHERE DATE(created_at) = p_date),
    (SELECT COUNT(DISTINCT mechanic_id) FROM part_requests WHERE DATE(created_at) = p_date),
    (SELECT COUNT(DISTINCT shop_id) FROM offers WHERE DATE(created_at) = p_date)
  ON CONFLICT (metric_date) DO UPDATE SET
    total_requests = EXCLUDED.total_requests,
    total_offers = EXCLUDED.total_offers,
    total_orders = EXCLUDED.total_orders,
    total_revenue_cents = EXCLUDED.total_revenue_cents,
    total_errors = EXCLUDED.total_errors,
    active_mechanics = EXCLUDED.active_mechanics,
    active_shops = EXCLUDED.active_shops;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. CLEANUP OLD METRICS (Data Retention)
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_old_monitoring_data()
RETURNS void AS $$
BEGIN
  -- Keep error logs for 90 days
  DELETE FROM error_logs WHERE created_at < NOW() - INTERVAL '90 days';
  
  -- Keep performance metrics for 30 days
  DELETE FROM performance_metrics WHERE recorded_at < NOW() - INTERVAL '30 days';
  
  -- Keep alert history for 180 days
  DELETE FROM alert_history WHERE created_at < NOW() - INTERVAL '180 days';
  
  -- Keep rate limit logs for 1 hour (already handled, but ensure)
  DELETE FROM rate_limit_log WHERE created_at < NOW() - INTERVAL '1 hour';
  
  RAISE NOTICE 'Monitoring data cleanup completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 11. RLS FOR MONITORING TABLES
-- =====================================================
-- Only admins should see monitoring data

ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_thresholds ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_metrics ENABLE ROW LEVEL SECURITY;

-- Service role can access all (for backend monitoring)
CREATE POLICY "Service role full access on error_logs" ON error_logs
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on performance_metrics" ON performance_metrics
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on alert_history" ON alert_history
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on alert_thresholds" ON alert_thresholds
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access on daily_metrics" ON daily_metrics
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- PASS 5 MONITORING SETUP COMPLETE
-- =====================================================
-- Summary:
-- ✅ error_logs table for tracking application errors
-- ✅ performance_metrics table for latency tracking
-- ✅ system_health_status view for real-time monitoring
-- ✅ alert_thresholds table for configurable alerts
-- ✅ alert_history table for tracking triggered alerts
-- ✅ check_and_create_alerts() function for automated alerting
-- ✅ Daily metrics aggregation for dashboards
-- ✅ Data retention cleanup functions
-- =====================================================

-- To check alerts manually:
-- SELECT * FROM check_and_create_alerts();

-- To view current health:
-- SELECT * FROM system_health_status;

-- To view unacknowledged alerts:
-- SELECT * FROM alert_history WHERE acknowledged = FALSE ORDER BY created_at DESC;
