-- Database Schema Initialization for Multitenant Time Tracker
-- This file creates the complete database schema matching the documented design

-- Enable UUID extension (using gen_random_uuid for modern PostgreSQL)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tenants table (root of multi-tenancy)
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_email TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create users table with tenant isolation
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, email)  -- Email unique per tenant
);

-- Create clients table with tenant isolation
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    contact_info TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create projects table with tenant isolation and client relationship
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, name)  -- Project name unique per tenant
);

-- Create technologies table with tenant isolation
CREATE TABLE IF NOT EXISTS technologies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create time_entries table (main tracking entity)
CREATE TABLE IF NOT EXISTS time_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create junction table for time entry-technology relationships
CREATE TABLE IF NOT EXISTS time_entry_technology (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    time_entry_id UUID NOT NULL REFERENCES time_entries(id) ON DELETE CASCADE,
    technology_id UUID NOT NULL REFERENCES technologies(id) ON DELETE CASCADE,
    UNIQUE(time_entry_id, technology_id)  -- Prevent duplicate associations
);

-- Create junction table for project-technology relationships
CREATE TABLE IF NOT EXISTS project_technology (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    technology_id UUID NOT NULL REFERENCES technologies(id) ON DELETE CASCADE,
    UNIQUE(project_id, technology_id)  -- Prevent duplicate associations
);

-- Create essential indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_clients_tenant_id ON clients(tenant_id);
CREATE INDEX IF NOT EXISTS idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX IF NOT EXISTS idx_projects_client_id ON projects(client_id);
CREATE INDEX IF NOT EXISTS idx_technologies_tenant_id ON technologies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_tenant_id ON time_entries(tenant_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_user_id ON time_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_project_id ON time_entries(project_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_start_time ON time_entries(start_time);
CREATE INDEX IF NOT EXISTS idx_time_entry_technology_time_entry_id ON time_entry_technology(time_entry_id);
CREATE INDEX IF NOT EXISTS idx_time_entry_technology_technology_id ON time_entry_technology(technology_id);
CREATE INDEX IF NOT EXISTS idx_project_technology_project_id ON project_technology(project_id);
CREATE INDEX IF NOT EXISTS idx_project_technology_technology_id ON project_technology(technology_id);

-- Additional indexes for dashboard queries and search
CREATE INDEX IF NOT EXISTS idx_tenants_name ON tenants(name);
CREATE INDEX IF NOT EXISTS idx_clients_tenant_name ON clients(tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_projects_tenant_name ON projects(tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_technologies_tenant_name ON technologies(tenant_id, name);
CREATE INDEX IF NOT EXISTS idx_time_entries_created_at ON time_entries(tenant_id, created_at);

-- Create function to ensure tenant isolation in time entries
CREATE OR REPLACE FUNCTION check_time_entry_tenant_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure user belongs to the same tenant
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = NEW.user_id AND tenant_id = NEW.tenant_id
    ) THEN
        RAISE EXCEPTION 'User must belong to the same tenant as the time entry';
    END IF;
    
    -- Ensure project belongs to the same tenant
    IF NOT EXISTS (
        SELECT 1 FROM projects 
        WHERE id = NEW.project_id AND tenant_id = NEW.tenant_id
    ) THEN
        RAISE EXCEPTION 'Project must belong to the same tenant as the time entry';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for tenant consistency check
CREATE TRIGGER check_time_entry_tenant_consistency_trigger
    BEFORE INSERT OR UPDATE ON time_entries
    FOR EACH ROW EXECUTE FUNCTION check_time_entry_tenant_consistency();

-- Create function to ensure project-client tenant consistency
CREATE OR REPLACE FUNCTION check_project_client_tenant_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure client belongs to the same tenant as the project
    IF NOT EXISTS (
        SELECT 1 FROM clients 
        WHERE id = NEW.client_id AND tenant_id = NEW.tenant_id
    ) THEN
        RAISE EXCEPTION 'Client must belong to the same tenant as the project';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for project-client tenant consistency
CREATE TRIGGER check_project_client_tenant_consistency_trigger
    BEFORE INSERT OR UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION check_project_client_tenant_consistency();

-- Create function to ensure technology associations are within same tenant
CREATE OR REPLACE FUNCTION check_time_entry_technology_tenant_consistency()
RETURNS TRIGGER AS $$
DECLARE
    entry_tenant_id UUID;
    tech_tenant_id UUID;
BEGIN
    -- Get tenant IDs for both time entry and technology
    SELECT te.tenant_id INTO entry_tenant_id 
    FROM time_entries te WHERE te.id = NEW.time_entry_id;
    
    SELECT t.tenant_id INTO tech_tenant_id 
    FROM technologies t WHERE t.id = NEW.technology_id;
    
    -- Ensure they belong to the same tenant
    IF entry_tenant_id != tech_tenant_id THEN
        RAISE EXCEPTION 'Technology must belong to the same tenant as the time entry';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for time entry technology tenant consistency
CREATE TRIGGER check_time_entry_technology_tenant_consistency_trigger
    BEFORE INSERT OR UPDATE ON time_entry_technology
    FOR EACH ROW EXECUTE FUNCTION check_time_entry_technology_tenant_consistency();

-- Create function to ensure project-technology associations are within same tenant
CREATE OR REPLACE FUNCTION check_project_technology_tenant_consistency()
RETURNS TRIGGER AS $$
DECLARE
    project_tenant_id UUID;
    tech_tenant_id UUID;
BEGIN
    -- Get tenant IDs for both project and technology
    SELECT p.tenant_id INTO project_tenant_id 
    FROM projects p WHERE p.id = NEW.project_id;
    
    SELECT t.tenant_id INTO tech_tenant_id 
    FROM technologies t WHERE t.id = NEW.technology_id;
    
    -- Ensure they belong to the same tenant
    IF project_tenant_id != tech_tenant_id THEN
        RAISE EXCEPTION 'Technology must belong to the same tenant as the project';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for project technology tenant consistency
CREATE TRIGGER check_project_technology_tenant_consistency_trigger
    BEFORE INSERT OR UPDATE ON project_technology
    FOR EACH ROW EXECUTE FUNCTION check_project_technology_tenant_consistency();

-- Insert sample data for testing and validation
INSERT INTO tenants (name, contact_email) VALUES 
    ('Demo Company', 'admin@democompany.com'),
    ('Test Organization', 'contact@testorg.com')
ON CONFLICT DO NOTHING;

-- Insert sample users
DO $$
DECLARE
    demo_tenant_id UUID;
    test_tenant_id UUID;
    demo_user_id UUID;
    test_user_id UUID;
BEGIN
    -- Get tenant IDs
    SELECT id INTO demo_tenant_id FROM tenants WHERE name = 'Demo Company';
    SELECT id INTO test_tenant_id FROM tenants WHERE name = 'Test Organization';
    
    -- Insert sample users for demo tenant
    IF demo_tenant_id IS NOT NULL THEN
        INSERT INTO users (tenant_id, email, name, password_hash, is_admin) VALUES 
            (demo_tenant_id, 'admin@democompany.com', 'Demo Admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4hJBEn.Edm', true),
            (demo_tenant_id, 'user@democompany.com', 'Demo User', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4hJBEn.Edm', false)
        ON CONFLICT (tenant_id, email) DO NOTHING;
    END IF;
    
    -- Insert sample users for test tenant
    IF test_tenant_id IS NOT NULL THEN
        INSERT INTO users (tenant_id, email, name, password_hash, is_admin) VALUES 
            (test_tenant_id, 'admin@testorg.com', 'Test Admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4hJBEn.Edm', true)
        ON CONFLICT (tenant_id, email) DO NOTHING;
    END IF;
END $$;

-- Insert sample clients and projects
DO $$
DECLARE
    demo_tenant_id UUID;
    test_tenant_id UUID;
    demo_client_id UUID;
    test_client_id UUID;
    demo_project_id UUID;
    test_project_id UUID;
BEGIN
    -- Get tenant IDs
    SELECT id INTO demo_tenant_id FROM tenants WHERE name = 'Demo Company';
    SELECT id INTO test_tenant_id FROM tenants WHERE name = 'Test Organization';
    
    -- Insert sample clients for demo tenant
    IF demo_tenant_id IS NOT NULL THEN
        INSERT INTO clients (tenant_id, name, contact_info, notes) VALUES 
            (demo_tenant_id, 'Acme Corp', 'contact@acmecorp.com', 'Main client for web development'),
            (demo_tenant_id, 'Beta Industries', 'info@betaindustries.com', 'Database consulting client')
        ON CONFLICT DO NOTHING
        RETURNING id INTO demo_client_id;
        
        -- Get the first client ID for projects
        SELECT id INTO demo_client_id FROM clients WHERE tenant_id = demo_tenant_id LIMIT 1;
        
        -- Insert sample projects
        IF demo_client_id IS NOT NULL THEN
            INSERT INTO projects (tenant_id, client_id, name, description, is_active) VALUES 
                (demo_tenant_id, demo_client_id, 'Website Redesign', 'Complete overhaul of company website', true),
                (demo_tenant_id, demo_client_id, 'Mobile App', 'iOS and Android mobile application', true)
            ON CONFLICT (tenant_id, name) DO NOTHING;
        END IF;
    END IF;
    
    -- Insert sample clients for test tenant
    IF test_tenant_id IS NOT NULL THEN
        INSERT INTO clients (tenant_id, name, contact_info, notes) VALUES 
            (test_tenant_id, 'Gamma Solutions', 'hello@gammasolutions.com', 'API development project')
        ON CONFLICT DO NOTHING;
        
        -- Get client ID and insert project
        SELECT id INTO test_client_id FROM clients WHERE tenant_id = test_tenant_id LIMIT 1;
        IF test_client_id IS NOT NULL THEN
            INSERT INTO projects (tenant_id, client_id, name, description, is_active) VALUES 
                (test_tenant_id, test_client_id, 'API Platform', 'RESTful API development', true)
            ON CONFLICT (tenant_id, name) DO NOTHING;
        END IF;
    END IF;
END $$;

-- Insert sample technologies
DO $$
DECLARE
    demo_tenant_id UUID;
    test_tenant_id UUID;
BEGIN
    -- Get tenant IDs
    SELECT id INTO demo_tenant_id FROM tenants WHERE name = 'Demo Company';
    SELECT id INTO test_tenant_id FROM tenants WHERE name = 'Test Organization';
    
    -- Insert sample technologies for demo tenant
    IF demo_tenant_id IS NOT NULL THEN
        INSERT INTO technologies (tenant_id, name, description, is_archived) VALUES 
            (demo_tenant_id, 'React', 'JavaScript library for building user interfaces', false),
            (demo_tenant_id, 'Node.js', 'JavaScript runtime for server-side development', false),
            (demo_tenant_id, 'PostgreSQL', 'Open source relational database', false),
            (demo_tenant_id, 'Python', 'High-level programming language', false),
            (demo_tenant_id, 'FastAPI', 'Modern web framework for building APIs', false)
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Insert sample technologies for test tenant
    IF test_tenant_id IS NOT NULL THEN
        INSERT INTO technologies (tenant_id, name, description, is_archived) VALUES 
            (test_tenant_id, 'Vue.js', 'Progressive JavaScript framework', false),
            (test_tenant_id, 'Express.js', 'Web application framework for Node.js', false),
            (test_tenant_id, 'MongoDB', 'Document-oriented database', false)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Create views for reporting and analytics
CREATE OR REPLACE VIEW time_tracking_summary AS
SELECT 
    te.tenant_id,
    u.name as user_name,
    c.name as client_name,
    p.name as project_name,
    DATE(te.start_time) as tracking_date,
    COUNT(*) as entry_count,
    COALESCE(SUM(EXTRACT(EPOCH FROM (te.end_time - te.start_time)) / 60), 0) as total_minutes,
    COALESCE(SUM(EXTRACT(EPOCH FROM (te.end_time - te.start_time)) / 3600), 0) as total_hours
FROM time_entries te
JOIN users u ON te.user_id = u.id
JOIN projects p ON te.project_id = p.id
JOIN clients c ON p.client_id = c.id
WHERE te.end_time IS NOT NULL
GROUP BY te.tenant_id, u.id, u.name, c.id, c.name, p.id, p.name, DATE(te.start_time);

-- Create view for active sessions (ongoing time entries)
CREATE OR REPLACE VIEW active_time_entries AS
SELECT 
    te.id,
    te.tenant_id,
    u.name as user_name,
    c.name as client_name,
    p.name as project_name,
    te.start_time,
    te.notes,
    EXTRACT(EPOCH FROM (NOW() - te.start_time)) / 60 as elapsed_minutes
FROM time_entries te
JOIN users u ON te.user_id = u.id
JOIN projects p ON te.project_id = p.id
JOIN clients c ON p.client_id = c.id
WHERE te.end_time IS NULL;

-- Add helpful comments
COMMENT ON TABLE tenants IS 'Root table for multi-tenant architecture - each tenant represents an organization/group';
COMMENT ON TABLE users IS 'User accounts with tenant isolation - users belong to exactly one tenant';
COMMENT ON TABLE clients IS 'Client information per tenant - clients are scoped to their tenant';
COMMENT ON TABLE projects IS 'Projects associated with clients per tenant - projects belong to a client within a tenant';
COMMENT ON TABLE technologies IS 'Technologies/tools used in projects per tenant - tech stack is tenant-specific';
COMMENT ON TABLE time_entries IS 'Time tracking entries - main entity for tracking work sessions';
COMMENT ON TABLE time_entry_technology IS 'Many-to-many relationship between time entries and technologies used';
COMMENT ON TABLE project_technology IS 'Many-to-many relationship between projects and their associated technologies';

COMMENT ON COLUMN users.is_admin IS 'Tenant-level admin privileges - can manage other users within the tenant';
COMMENT ON COLUMN projects.is_active IS 'Soft delete flag - inactive projects are archived but not deleted';
COMMENT ON COLUMN technologies.is_archived IS 'Archival flag for technologies no longer in use';

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE '=== DATABASE SCHEMA INITIALIZATION COMPLETED ===';
    RAISE NOTICE 'Created tables: tenants, users, clients, projects, technologies, time_entries, time_entry_technology, project_technology';
    RAISE NOTICE 'Created indexes for performance optimization';
    RAISE NOTICE 'Created triggers for data consistency and tenant isolation';
    RAISE NOTICE 'Created sample data for testing';
    RAISE NOTICE 'Created views for reporting and analytics';
    RAISE NOTICE 'Database schema matches the documented design in database-schema.md';
    RAISE NOTICE 'Database is ready for the multitenant time tracker application';
END $$;
