#!/usr/bin/env python3
"""
Database Test Runner for Multitenant Time Tracker

This script runs the SQL-based database validation tests and provides
programmatic test execution with proper reporting.
"""

import psycopg2
import sys
import os
from typing import List, Tuple
import re
from datetime import datetime

class DatabaseTestRunner:
    def __init__(self, connection_string: str):
        """Initialize the test runner with database connection."""
        self.connection_string = connection_string
        self.connection = None
        self.test_results = []
        
    def connect(self) -> bool:
        """Establish database connection."""
        try:
            self.connection = psycopg2.connect(self.connection_string)
            self.connection.set_session(autocommit=True)
            print("✓ Database connection established")
            return True
        except Exception as e:
            print(f"✗ Failed to connect to database: {e}")
            return False
    
    def disconnect(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()
            print("✓ Database connection closed")
    
    def run_sql_test_file(self, test_file_path: str) -> List[Tuple[str, bool, str]]:
        """
        Run SQL test file and capture results.
        Returns list of (test_name, passed, message) tuples.
        """
        if not os.path.exists(test_file_path):
            print(f"✗ Test file not found: {test_file_path}")
            return []
        
        try:
            with open(test_file_path, 'r') as f:
                sql_content = f.read()
            
            cursor = self.connection.cursor()
            
            # Enable notice capturing
            notices = []
            def notice_handler(diag):
                notices.append(diag.message_primary)
            
            self.connection.add_notice_processor(notice_handler)
            
            # Execute the SQL test file
            try:
                cursor.execute(sql_content)
                
                # Process notices to extract test results
                test_results = []
                for notice in notices:
                    if "TEST PASSED:" in notice:
                        test_name = notice.replace("TEST PASSED:", "").strip()
                        test_results.append((test_name, True, notice))
                    elif "TEST FAILED:" in notice:
                        test_name = notice.replace("TEST FAILED:", "").strip()
                        test_results.append((test_name, False, notice))
                    elif "TEST SKIPPED:" in notice:
                        test_name = notice.replace("TEST SKIPPED:", "").strip()
                        test_results.append((test_name, None, notice))
                
                cursor.close()
                return test_results
                
            except psycopg2.Error as e:
                # If there's a SQL error, it's likely a test failure
                error_msg = str(e).strip()
                if "TEST FAILED:" in error_msg:
                    # Extract test name from error message
                    test_name = "Database validation"
                    test_results.append((test_name, False, error_msg))
                else:
                    test_results.append(("SQL Execution", False, f"SQL Error: {error_msg}"))
                cursor.close()
                return test_results
                
        except Exception as e:
            print(f"✗ Error running test file: {e}")
            return [("File execution", False, str(e))]
    
    def run_individual_tests(self) -> List[Tuple[str, bool, str]]:
        """Run individual database validation tests."""
        tests = []
        cursor = self.connection.cursor()
        
        # Test 1: Database connectivity
        try:
            cursor.execute("SELECT 1")
            tests.append(("Database connectivity", True, "Connection successful"))
        except Exception as e:
            tests.append(("Database connectivity", False, f"Connection failed: {e}"))
            return tests
        
        # Test 2: Check if database is empty (for fresh installation testing)
        try:
            cursor.execute("""
                SELECT COUNT(*) FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            """)
            table_count = cursor.fetchone()[0]
            
            if table_count == 0:
                tests.append(("Database schema", False, "No tables found - schema needs to be created"))
            else:
                tests.append(("Database schema", True, f"Found {table_count} tables"))
        except Exception as e:
            tests.append(("Database schema check", False, f"Error checking schema: {e}"))
        
        # Test 3: Check PostgreSQL version compatibility
        try:
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            
            # Extract major version number
            version_match = re.search(r'PostgreSQL (\d+)', version)
            if version_match:
                major_version = int(version_match.group(1))
                if major_version >= 12:
                    tests.append(("PostgreSQL version", True, f"Compatible version: {version}"))
                else:
                    tests.append(("PostgreSQL version", False, f"Version too old: {version}"))
            else:
                tests.append(("PostgreSQL version", True, f"Version detected: {version}"))
        except Exception as e:
            tests.append(("PostgreSQL version", False, f"Error checking version: {e}"))
        
        # Test 4: Check database permissions
        try:
            cursor.execute("CREATE TEMP TABLE test_permissions (id INTEGER)")
            cursor.execute("DROP TABLE test_permissions")
            tests.append(("Database permissions", True, "CREATE/DROP permissions verified"))
        except Exception as e:
            tests.append(("Database permissions", False, f"Insufficient permissions: {e}"))
        
        # Test 5: Check UUID extension availability
        try:
            cursor.execute("SELECT gen_random_uuid()")
            tests.append(("UUID support", True, "UUID generation available"))
        except Exception as e:
            # Try to enable the extension
            try:
                cursor.execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")
                cursor.execute("SELECT uuid_generate_v4()")
                tests.append(("UUID support", True, "UUID extension enabled"))
            except Exception as e2:
                tests.append(("UUID support", False, f"UUID support unavailable: {e2}"))
        
        cursor.close()
        return tests
    
    def generate_report(self, all_results: List[Tuple[str, bool, str]]) -> str:
        """Generate a formatted test report."""
        passed = sum(1 for _, status, _ in all_results if status is True)
        failed = sum(1 for _, status, _ in all_results if status is False)
        skipped = sum(1 for _, status, _ in all_results if status is None)
        total = len(all_results)
        
        report = []
        report.append("=" * 60)
        report.append("DATABASE VALIDATION TEST REPORT")
        report.append("=" * 60)
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"Total Tests: {total}")
        report.append(f"Passed: {passed}")
        report.append(f"Failed: {failed}")
        report.append(f"Skipped: {skipped}")
        report.append("")
        
        # Group results by status
        if failed > 0:
            report.append("FAILED TESTS:")
            report.append("-" * 40)
            for test_name, status, message in all_results:
                if status is False:
                    report.append(f"✗ {test_name}")
                    report.append(f"  {message}")
            report.append("")
        
        if passed > 0:
            report.append("PASSED TESTS:")
            report.append("-" * 40)
            for test_name, status, message in all_results:
                if status is True:
                    report.append(f"✓ {test_name}")
            report.append("")
        
        if skipped > 0:
            report.append("SKIPPED TESTS:")
            report.append("-" * 40)
            for test_name, status, message in all_results:
                if status is None:
                    report.append(f"- {test_name}")
                    report.append(f"  {message}")
            report.append("")
        
        # Overall result
        if failed == 0:
            report.append("OVERALL RESULT: ✓ ALL TESTS PASSED")
        else:
            report.append(f"OVERALL RESULT: ✗ {failed} TEST(S) FAILED")
        
        report.append("=" * 60)
        return "\n".join(report)
    
    def run_all_tests(self, sql_test_file: str = None) -> bool:
        """Run all database tests and return success status."""
        if not self.connect():
            return False
        
        try:
            all_results = []
            
            # Run individual connectivity and setup tests
            print("Running individual database tests...")
            individual_results = self.run_individual_tests()
            all_results.extend(individual_results)
            
            # Run SQL test file if provided
            if sql_test_file:
                print(f"Running SQL test file: {sql_test_file}")
                sql_results = self.run_sql_test_file(sql_test_file)
                all_results.extend(sql_results)
            
            # Generate and display report
            report = self.generate_report(all_results)
            print("\n" + report)
            
            # Save report to file
            report_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
            with open(report_file, 'w') as f:
                f.write(report)
            print(f"\nTest report saved to: {report_file}")
            
            # Return success if no failures
            failed_count = sum(1 for _, status, _ in all_results if status is False)
            return failed_count == 0
            
        finally:
            self.disconnect()

def main():
    """Main function to run database tests."""
    # Get connection string from file or environment
    connection_string = None
    
    # Try to read from db_connection.txt
    if os.path.exists('db_connection.txt'):
        with open('db_connection.txt', 'r') as f:
            connection_string = f.read().strip()
        print(f"Using connection string from db_connection.txt")
    
    # Try environment variables as fallback
    if not connection_string:
        db_host = os.getenv('POSTGRES_HOST', 'localhost')
        db_port = os.getenv('POSTGRES_PORT', '5000')
        db_name = os.getenv('POSTGRES_DB', 'myapp')
        db_user = os.getenv('POSTGRES_USER', 'appuser')
        db_password = os.getenv('POSTGRES_PASSWORD', 'dbuser123')
        
        connection_string = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
        print(f"Using connection string from environment variables")
    
    if not connection_string:
        print("✗ No database connection information found")
        print("Please ensure db_connection.txt exists or set environment variables:")
        print("  POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD")
        sys.exit(1)
    
    # Initialize test runner
    runner = DatabaseTestRunner(connection_string)
    
    # Determine SQL test file path
    sql_test_file = "test_database_validation.sql"
    if not os.path.exists(sql_test_file):
        sql_test_file = None
        print("⚠ SQL test file not found, running individual tests only")
    
    # Run tests
    success = runner.run_all_tests(sql_test_file)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
