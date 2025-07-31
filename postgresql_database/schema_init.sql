-- Database Schema Initialization for Multitenant Time Tracker
-- This file creates the complete database schema that the validation tests expect

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tenants table (root of multi-tenancy)
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Create users table with tenant isolation
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(email, tenant_id)  -- Email unique per tenant
);

-- Create clients table with tenant isolation
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create projects table with tenant isolation and client relationship
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    hourly_rate NUMERIC(10,2),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(name, tenant_id)  -- Project name unique per tenant
);

-- Create technologies table with tenant isolation
CREATE TABLE IF NOT EXISTS technologies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create time_entries table (main tracking entity)
CREATE TABLE IF NOT EXISTS time_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    description TEXT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    is_billable BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create junction table for project-technology relationships
CREATE TABLE IF NOT EXISTS project_technologies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    technology_id UUID NOT NULL REFERENCES technologies(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
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
CREATE INDEX IF NOT EXISTS idx_project_technologies_project_id ON project_technologies(project_id);
CREATE INDEX IF NOT EXISTS idx_project_technologies_technology_id ON project_technologies(technology_id);

-- Create function to automatically update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_technologies_updated_at BEFORE UPDATE ON technologies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_time_entries_updated_at BEFORE UPDATE ON time_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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
    
    -- Calculate duration if end_time is provided
    IF NEW.end_time IS NOT NULL AND NEW.start_time IS NOT NULL THEN
        NEW.duration_minutes = EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time)) / 60;
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

-- Insert sample data for testing (optional - can be used for seed data tests)
INSERT INTO tenants (name, slug) VALUES 
    ('Demo Company', 'demo-company'),
    ('Test Organization', 'test-org')
ON CONFLICT (slug) DO NOTHING;

-- Insert sample technologies that can be shared across tenants for demonstration
DO $$
DECLARE
    demo_tenant_id UUID;
    test_tenant_id UUID;
BEGIN
    -- Get tenant IDs
    SELECT id INTO demo_tenant_id FROM tenants WHERE slug = 'demo-company';
    SELECT id INTO test_tenant_id FROM tenants WHERE slug = 'test-org';
    
    -- Insert sample technologies for demo tenant
    IF demo_tenant_id IS NOT NULL THEN
        INSERT INTO technologies (tenant_id, name, description, category) VALUES 
            (demo_tenant_id, 'React', 'JavaScript library for building user interfaces', 'Frontend'),
            (demo_tenant_id, 'Node.js', 'JavaScript runtime for server-side development', 'Backend'),
            (demo_tenant_id, 'PostgreSQL', 'Open source relational database', 'Database'),
            (demo_tenant_id, 'Python', 'High-level programming language', 'Backend'),
            (demo_tenant_id, 'FastAPI', 'Modern web framework for building APIs', 'Backend')
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Insert sample technologies for test tenant
    IF test_tenant_id IS NOT NULL THEN
        INSERT INTO technologies (tenant_id, name, description, category) VALUES 
            (test_tenant_id, 'Vue.js', 'Progressive JavaScript framework', 'Frontend'),
            (test_tenant_id, 'Express.js', 'Web application framework for Node.js', 'Backend'),
            (test_tenant_id, 'MongoDB', 'Document-oriented database', 'Database')
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Create view for time tracking summary (useful for reporting)
CREATE OR REPLACE VIEW time_tracking_summary AS
SELECT 
    te.tenant_id,
    u.first_name || ' ' || u.last_name as user_name,
    c.name as client_name,
    p.name as project_name,
    DATE(te.start_time) as tracking_date,
    SUM(COALESCE(te.duration_minutes, 0)) as total_minutes,
    SUM(COALESCE(te.duration_minutes, 0)) / 60.0 as total_hours,
    COUNT(*) as entry_count,
    SUM(CASE WHEN te.is_billable THEN COALESCE(te.duration_minutes, 0) ELSE 0 END) as billable_minutes
FROM time_entries te
JOIN users u ON te.user_id = u.id
JOIN projects p ON te.project_id = p.id
JOIN clients c ON p.client_id = c.id
WHERE te.end_time IS NOT NULL
GROUP BY te.tenant_id, u.id, u.first_name, u.last_name, c.id, c.name, p.id, p.name, DATE(te.start_time);

-- Grant appropriate permissions (adjust as needed for your environment)
-- Note: In production, create specific roles with minimal required permissions

COMMENT ON TABLE tenants IS 'Root table for multi-tenant architecture';
COMMENT ON TABLE users IS 'User accounts with tenant isolation';
COMMENT ON TABLE clients IS 'Client information per tenant';
COMMENT ON TABLE projects IS 'Projects associated with clients per tenant';
COMMENT ON TABLE technologies IS 'Technologies/tools used in projects per tenant';
COMMENT ON TABLE time_entries IS 'Time tracking entries with full audit trail';
COMMENT ON TABLE project_technologies IS 'Many-to-many relationship between projects and technologies';

COMMENT ON COLUMN tenants.slug IS 'URL-friendly unique identifier for tenant';
COMMENT ON COLUMN users.role IS 'User role within tenant (admin, manager, user, etc.)';
COMMENT ON COLUMN time_entries.duration_minutes IS 'Calculated field updated automatically from start/end times';
COMMENT ON COLUMN time_entries.is_billable IS 'Whether this time entry should be included in client billing';

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE '=== DATABASE SCHEMA INITIALIZATION COMPLETED ===';
    RAISE NOTICE 'Created tables: tenants, users, clients, projects, technologies, time_entries, project_technologies';
    RAISE NOTICE 'Created indexes for performance optimization';
    RAISE NOTICE 'Created triggers for data consistency and automatic timestamp updates';
    RAISE NOTICE 'Created sample data for testing';
    RAISE NOTICE 'Database is ready for the multitenant time tracker application';
END $$;
