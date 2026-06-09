-- AI Support Copilot: Multi-Tenant Database Schema & Optimization Indexes

-- Enable UUID extension for secure, unguessable primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. SCHEMA DEFINITION

-- Tenants Table: Represents the corporate clients using the SaaS platform
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL
);

-- Tickets Table: Represents customer support issues linked to a specific tenant
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id),
    status VARCHAR(50) NOT NULL,
    priority VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    description TEXT
);


-- 2. QUERY OPTIMIZATION PROFILE (INDEXES)
-- Note: Indexes are created CONCURRENTLY to prevent table locking in production.

-- Challenge 1: The Composite Index
-- Optimizes multi-tenant dashboard queries (fetching recent tickets per company).
-- Reduces O(N) Seq Scan to O(log N) Index Scan.
CREATE INDEX CONCURRENTLY idx_tickets_tenant_date 
ON tickets (tenant_id, created_at DESC);

-- Challenge 2: The Partial Index
-- Optimizes priority queue processing for background workers/support agents.
-- Conserves RAM and disk space by ONLY indexing active, critical issues.
CREATE INDEX CONCURRENTLY idx_open_critical_tickets 
ON tickets (created_at ASC) 
WHERE status = 'open' AND priority = 'critical';

-- Challenge 3: The GIN Index for JSONB
-- Optimizes unstructured metadata searches (e.g., finding tickets where OS="Linux").
-- Enables high-speed containment (@>) lookups inside JSON blobs.
CREATE INDEX CONCURRENTLY idx_tickets_metadata 
ON tickets USING GIN (metadata);

-- Challenge 4: Full-Text Search (tsvector + GIN)
-- Resolves the leading-wildcard bottleneck (ILIKE '%keyword%').
-- Generates lexemes from paragraphs to allow instant keyword lookups.
ALTER TABLE tickets 
ADD COLUMN text_search tsvector 
GENERATED ALWAYS AS (to_tsvector('english', description)) STORED;

CREATE INDEX CONCURRENTLY idx_tickets_text_search 
ON tickets USING GIN (text_search);

-- Challenge 5: The Foreign Key Index
-- Prevents N+1 aggregation killers and Hash Join bottlenecks.
-- Explicitly indexes the foreign key to allow instant JOINs between tenants and tickets.
CREATE INDEX CONCURRENTLY idx_tickets_tenant_id 
ON tickets (tenant_id);