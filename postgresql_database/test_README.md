# Database Validation Tests for Multitenant Time Tracker

This directory contains comprehensive database validation tests designed to ensure the PostgreSQL database schema meets all requirements for the multitenant time tracker application.

## Test Files

### `test_database_validation.sql`
Comprehensive SQL-based test suite that validates:
- Table existence and structure
- Field types and constraints
- Primary and foreign key relationships
- Multi-tenancy enforcement (tenant isolation)
- Uniqueness constraints
- Index existence for performance
- Referential integrity
- Sample data validation

### `test_database_runner.py`
Python script that:
- Connects to the PostgreSQL database
- Executes validation tests programmatically
- Provides detailed test reports
- Supports both individual tests and SQL file execution
- Generates timestamped test reports

### `schema_init.sql`
Complete database schema initialization script that creates:
- All required tables with proper relationships
- Indexes for optimal performance
- Triggers for data consistency
- Functions for tenant isolation enforcement
- Sample data for testing
- Views for reporting

## Prerequisites

1. **PostgreSQL Database**: Ensure PostgreSQL server is running and accessible
2. **Python Dependencies**: Install required Python packages
   ```bash
   pip install psycopg2-binary
   ```
3. **Database Connection**: Ensure connection details are available

## Running the Tests

### Method 1: Using Python Test Runner (Recommended)

```bash
# Navigate to the postgresql_database directory
cd multitenant-time-tracker-94699-61450/postgresql_database

# Run the test runner
python test_database_runner.py
```

The test runner will:
- Automatically detect connection details from `db_connection.txt` or environment variables
- Run individual connectivity and setup tests
- Execute the SQL validation test suite
- Generate a detailed report
- Save results to a timestamped report file

### Method 2: Direct SQL Execution

```bash
# Connect to the database and run tests directly
psql postgresql://appuser:dbuser123@localhost:5000/myapp -f test_database_validation.sql
```

### Method 3: Initialize Schema First (for new databases)

If you're setting up a new database, run the schema initialization first:

```bash
# Initialize the database schema
psql postgresql://appuser:dbuser123@localhost:5000/myapp -f schema_init.sql

# Then run the validation tests
python test_database_runner.py
```

## Connection Configuration

The test runner looks for database connection information in this order:

1. **db_connection.txt file** (if present in the same directory)
2. **Environment variables**:
   - `POSTGRES_HOST` (default: localhost)
   - `POSTGRES_PORT` (default: 5000)
   - `POSTGRES_DB` (default: myapp)
   - `POSTGRES_USER` (default: appuser)
   - `POSTGRES_PASSWORD` (default: dbuser123)

### Setting Environment Variables

```bash
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5000
export POSTGRES_DB=myapp
export POSTGRES_USER=appuser
export POSTGRES_PASSWORD=dbuser123
```

## Test Categories

### 1. Schema Validation Tests
- Verify all required tables exist
- Check table column definitions and data types
- Validate primary key constraints
- Verify foreign key relationships

### 2. Multi-Tenancy Tests
- Ensure all tables have tenant_id columns where required
- Validate tenant isolation constraints
- Check cross-tenant reference prevention
- Verify tenant-specific uniqueness constraints

### 3. Data Integrity Tests
- Test referential integrity between related tables
- Validate business logic constraints
- Check automatic timestamp updates
- Verify calculated field updates

### 4. Performance Tests
- Confirm essential indexes exist
- Validate query performance optimizations
- Check tenant-based index strategies

### 5. Sample Data Tests
- Verify seed data correctness
- Test data consistency across related tables
- Validate sample data follows business rules

## Expected Database Schema

The tests expect the following tables:

- **tenants**: Root table for multi-tenancy
- **users**: User accounts with tenant isolation
- **clients**: Client information per tenant
- **projects**: Projects associated with clients
- **technologies**: Technologies/tools used in projects
- **time_entries**: Main time tracking entries
- **project_technologies**: Junction table for project-technology relationships

## Test Results Interpretation

### Test Status Types
- **✓ PASSED**: Test completed successfully
- **✗ FAILED**: Test failed - action required
- **- SKIPPED**: Test skipped (usually due to missing data/schema)

### Common Failure Scenarios
1. **Missing tables**: Run `schema_init.sql` to create required tables
2. **Incorrect column types**: Check table definitions against schema
3. **Missing constraints**: Verify foreign keys and unique constraints exist
4. **Missing indexes**: Create performance indexes as specified in schema
5. **Tenant isolation failures**: Check tenant_id columns and constraints

## Troubleshooting

### Connection Issues
- Verify PostgreSQL server is running
- Check connection parameters in `db_connection.txt`
- Ensure database user has required permissions
- Confirm database exists and is accessible

### Permission Issues
- Grant CREATE/DROP permissions for test execution
- Ensure user can create temporary tables for testing
- Verify schema modification permissions if needed

### Schema Issues
- Run `schema_init.sql` to create missing tables
- Compare existing schema with expected structure
- Check for naming conflicts or case sensitivity issues

## Integration with CI/CD

The Python test runner returns appropriate exit codes:
- `0`: All tests passed
- `1`: One or more tests failed

This allows integration with continuous integration systems:

```bash
# In CI pipeline
python test_database_runner.py
if [ $? -ne 0 ]; then
    echo "Database tests failed"
    exit 1
fi
```

## Maintenance

### Adding New Tests
1. Add SQL test blocks to `test_database_validation.sql`
2. Use the established pattern with `DO $$` blocks
3. Include appropriate `RAISE NOTICE` or `RAISE EXCEPTION` statements
4. Update this README with new test descriptions

### Updating Schema
1. Modify `schema_init.sql` with new table definitions
2. Update validation tests to match new schema requirements
3. Test changes against both new and existing databases
4. Update documentation accordingly

## Support

For issues with the database tests:
1. Check the generated test report for specific error details
2. Verify database connection and permissions
3. Ensure schema matches expected structure
4. Review PostgreSQL logs for detailed error information
