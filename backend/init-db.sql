-- Database initialization script
-- This script runs when PostgreSQL container starts for the first time

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create indexes for better performance
-- These will be created automatically by SQLAlchemy, but we can add custom ones here

-- Index for timing data queries
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_timing_data_circuit_timestamp 
-- ON timing_data(circuit_id, timestamp DESC);

-- Index for connection logs
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_connection_logs_circuit_timestamp 
-- ON connection_logs(circuit_id, timestamp DESC);

-- Full-text search index for patterns (if needed)
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_circuit_analysis_patterns_gin
-- ON circuit_analysis USING gin(patterns);

-- Vacuum and analyze for initial performance
VACUUM ANALYZE;