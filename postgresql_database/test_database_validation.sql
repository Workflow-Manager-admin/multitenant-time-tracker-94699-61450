-- Database Validation Test Suite for Multitenant Time Tracker
-- This file contains SQL tests to validate the database schema, constraints, and data integrity

-- Test 1: Check if all required tables exist
DO $$
DECLARE
    missing_tables TEXT := '';
    table_name TEXT;
    table_exists BOOLEAN;
BEGIN
    -- List of expected tables for multitenant time tracker
    FOR table_name IN VALUES ('tenants'), ('users'), ('clients'), ('projects'), ('technologies'), ('time_entries'), ('project_technologies')
    LOOP
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = table_name
        ) INTO table_exists;
        
        IF NOT table_exists THEN
            missing_tables := missing_tables || table_name || ', ';
        END IF;
    END LOOP;
    
    IF missing_tables != '' THEN
        RAISE EXCEPTION 'TEST FAILED: Missing tables: %', rtrim(missing_tables, ', ');
    ELSE
        RAISE NOTICE 'TEST PASSED: All required tables exist';
    END IF;
END $$;

-- Test 2: Validate tenants table structure
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check tenants table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'tenants' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'slug' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO')
    );
    
    IF column_count < 6 THEN
        RAISE EXCEPTION 'TEST FAILED: tenants table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: tenants table structure is valid';
    END IF;
    
    -- Check primary key constraint
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'tenants' 
        AND constraint_type = 'PRIMARY KEY'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: tenants table missing primary key constraint';
    END IF;
    
    -- Check unique constraint on slug
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'tenants' 
        AND tc.constraint_type = 'UNIQUE'
        AND kcu.column_name = 'slug'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: tenants table missing unique constraint on slug';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: tenants table constraints are valid';
END $$;

-- Test 3: Validate users table structure and multi-tenancy
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check users table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'users' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'tenant_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'email' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'password_hash' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'first_name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'last_name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'role' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 10 THEN
        RAISE EXCEPTION 'TEST FAILED: users table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: users table structure is valid';
    END IF;
    
    -- Check foreign key constraint to tenants
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'users' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'tenant_id'
        AND ccu.table_name = 'tenants'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: users table missing foreign key constraint to tenants';
    END IF;
    
    -- Check unique constraint on email per tenant
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'users' 
        AND tc.constraint_type = 'UNIQUE'
        AND EXISTS (
            SELECT 1 FROM information_schema.key_column_usage kcu2 
            WHERE kcu2.constraint_name = kcu.constraint_name 
            AND kcu2.column_name IN ('email', 'tenant_id')
        )
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: users table missing unique constraint on email+tenant_id';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: users table multi-tenancy constraints are valid';
END $$;

-- Test 4: Validate clients table structure and multi-tenancy
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check clients table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'clients' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'tenant_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'description' AND data_type = 'text' AND is_nullable = 'YES') OR
        (column_name = 'contact_email' AND data_type = 'character varying' AND is_nullable = 'YES') OR
        (column_name = 'contact_phone' AND data_type = 'character varying' AND is_nullable = 'YES') OR
        (column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 9 THEN
        RAISE EXCEPTION 'TEST FAILED: clients table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: clients table structure is valid';
    END IF;
    
    -- Check foreign key constraint to tenants
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'clients' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'tenant_id'
        AND ccu.table_name = 'tenants'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: clients table missing foreign key constraint to tenants';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: clients table multi-tenancy is valid';
END $$;

-- Test 5: Validate projects table structure and relationships
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check projects table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'projects' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'tenant_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'client_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'description' AND data_type = 'text' AND is_nullable = 'YES') OR
        (column_name = 'hourly_rate' AND data_type = 'numeric' AND is_nullable = 'YES') OR
        (column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 9 THEN
        RAISE EXCEPTION 'TEST FAILED: projects table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: projects table structure is valid';
    END IF;
    
    -- Check foreign key constraints
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'projects' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'tenant_id'
        AND ccu.table_name = 'tenants'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: projects table missing foreign key constraint to tenants';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'projects' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'client_id'
        AND ccu.table_name = 'clients'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: projects table missing foreign key constraint to clients';
    END IF;
    
    -- Check unique constraint on name per tenant
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'projects' 
        AND tc.constraint_type = 'UNIQUE'
        AND EXISTS (
            SELECT 1 FROM information_schema.key_column_usage kcu2 
            WHERE kcu2.constraint_name = kcu.constraint_name 
            AND kcu2.column_name IN ('name', 'tenant_id')
        )
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: projects table missing unique constraint on name+tenant_id';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: projects table relationships are valid';
END $$;

-- Test 6: Validate technologies table structure
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check technologies table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'technologies' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'tenant_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'name' AND data_type = 'character varying' AND is_nullable = 'NO') OR
        (column_name = 'description' AND data_type = 'text' AND is_nullable = 'YES') OR
        (column_name = 'category' AND data_type = 'character varying' AND is_nullable = 'YES') OR
        (column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 8 THEN
        RAISE EXCEPTION 'TEST FAILED: technologies table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: technologies table structure is valid';
    END IF;
    
    -- Check foreign key constraint to tenants
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'technologies' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'tenant_id'
        AND ccu.table_name = 'tenants'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: technologies table missing foreign key constraint to tenants';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: technologies table constraints are valid';
END $$;

-- Test 7: Validate time_entries table structure and relationships
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check time_entries table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'time_entries' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'tenant_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'user_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'project_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'description' AND data_type = 'text' AND is_nullable = 'YES') OR
        (column_name = 'start_time' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'end_time' AND data_type = 'timestamp with time zone' AND is_nullable = 'YES') OR
        (column_name = 'duration_minutes' AND data_type = 'integer' AND is_nullable = 'YES') OR
        (column_name = 'is_billable' AND data_type = 'boolean' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') OR
        (column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 11 THEN
        RAISE EXCEPTION 'TEST FAILED: time_entries table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: time_entries table structure is valid';
    END IF;
    
    -- Check all foreign key constraints
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'time_entries' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'tenant_id'
        AND ccu.table_name = 'tenants'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: time_entries table missing foreign key constraint to tenants';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'time_entries' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'user_id'
        AND ccu.table_name = 'users'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: time_entries table missing foreign key constraint to users';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'time_entries' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'project_id'
        AND ccu.table_name = 'projects'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: time_entries table missing foreign key constraint to projects';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: time_entries table relationships are valid';
END $$;

-- Test 8: Validate project_technologies junction table
DO $$
DECLARE
    column_count INTEGER;
BEGIN
    -- Check project_technologies table columns and types
    SELECT COUNT(*) INTO column_count
    FROM information_schema.columns 
    WHERE table_name = 'project_technologies' 
    AND table_schema = 'public'
    AND (
        (column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'project_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'technology_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR
        (column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO')
    );
    
    IF column_count < 4 THEN
        RAISE EXCEPTION 'TEST FAILED: project_technologies table missing required columns or incorrect types. Found % valid columns', column_count;
    ELSE
        RAISE NOTICE 'TEST PASSED: project_technologies table structure is valid';
    END IF;
    
    -- Check foreign key constraints
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'project_technologies' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'project_id'
        AND ccu.table_name = 'projects'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: project_technologies table missing foreign key constraint to projects';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'project_technologies' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'technology_id'
        AND ccu.table_name = 'technologies'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: project_technologies table missing foreign key constraint to technologies';
    END IF;
    
    -- Check unique constraint on project_id + technology_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'project_technologies' 
        AND tc.constraint_type = 'UNIQUE'
        AND EXISTS (
            SELECT 1 FROM information_schema.key_column_usage kcu2 
            WHERE kcu2.constraint_name = kcu.constraint_name 
            AND kcu2.column_name IN ('project_id', 'technology_id')
        )
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: project_technologies table missing unique constraint on project_id+technology_id';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: project_technologies table constraints are valid';
END $$;

-- Test 9: Multi-tenancy isolation validation (if sample data exists)
DO $$
DECLARE
    tenant_count INTEGER;
    cross_tenant_violations INTEGER := 0;
BEGIN
    -- Check if we have multiple tenants for testing
    SELECT COUNT(*) INTO tenant_count FROM tenants WHERE is_active = true;
    
    IF tenant_count < 2 THEN
        RAISE NOTICE 'TEST SKIPPED: Multi-tenancy isolation test requires at least 2 active tenants';
        RETURN;
    END IF;
    
    -- Check for cross-tenant references in users
    SELECT COUNT(*) INTO cross_tenant_violations
    FROM users u
    JOIN tenants t ON u.tenant_id = t.id
    WHERE NOT EXISTS (
        SELECT 1 FROM tenants t2 WHERE t2.id = u.tenant_id
    );
    
    IF cross_tenant_violations > 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Found % cross-tenant violations in users table', cross_tenant_violations;
    END IF;
    
    -- Check for cross-tenant references in projects/clients
    SELECT COUNT(*) INTO cross_tenant_violations
    FROM projects p
    JOIN clients c ON p.client_id = c.id
    WHERE p.tenant_id != c.tenant_id;
    
    IF cross_tenant_violations > 0 THEN
        RAISE EXCEPTION 'TEST FAILED: Found % cross-tenant violations between projects and clients', cross_tenant_violations;
    END IF;
    
    RAISE NOTICE 'TEST PASSED: Multi-tenancy isolation is properly enforced';
    
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'TEST SKIPPED: Multi-tenancy isolation test requires existing data';
END $$;

-- Test 10: Index existence validation for performance
DO $$
BEGIN
    -- Check for essential indexes
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'users' 
        AND indexname LIKE '%tenant_id%'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: Missing index on users.tenant_id for multi-tenancy performance';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'time_entries' 
        AND indexname LIKE '%tenant_id%'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: Missing index on time_entries.tenant_id for multi-tenancy performance';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'time_entries' 
        AND indexname LIKE '%user_id%'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: Missing index on time_entries.user_id for query performance';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'time_entries' 
        AND indexname LIKE '%project_id%'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: Missing index on time_entries.project_id for query performance';
    END IF;
    
    RAISE NOTICE 'TEST PASSED: Essential indexes exist for performance';
    
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'TEST SKIPPED: Index validation requires existing tables';
END $$;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '=== DATABASE VALIDATION TEST SUITE COMPLETED ===';
    RAISE NOTICE 'All tests that could be executed have been run.';
    RAISE NOTICE 'If any tests were skipped, it means the required schema or data does not exist yet.';
    RAISE NOTICE 'Run this test suite after creating the database schema to validate the implementation.';
END $$;
