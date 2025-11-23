#!/usr/bin/env bash
#
# Database Optimization - Optimize and maintain databases
# Supports MySQL/MariaDB and PostgreSQL
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DB_TYPE=""
DRY_RUN=false

#######################################
# Print colored output
#######################################
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
Database Optimization - Optimize and maintain databases

USAGE:
    $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
    analyze                 Analyze database performance
    optimize                Optimize all tables
    check                   Check tables for errors
    repair                  Repair corrupted tables
    vacuum                  Vacuum database (PostgreSQL)
    slow-queries            Show slow queries
    connections             Show active connections
    stats                   Show database statistics

OPTIONS:
    --type TYPE             Database type (mysql, postgresql)
    --database DB           Database name
    --dry-run               Show what would be done
    --help                  Show this help message

EXAMPLES:
    # Analyze MySQL performance
    $(basename "$0") analyze --type mysql

    # Optimize all MySQL tables
    $(basename "$0") optimize --type mysql --database myapp

    # Check PostgreSQL tables
    $(basename "$0") check --type postgresql

    # Show slow queries
    $(basename "$0") slow-queries --type mysql

    # Show database stats
    $(basename "$0") stats --type postgresql

EOF
}

#######################################
# Detect database type
#######################################
detect_db_type() {
    if [[ -n "$DB_TYPE" ]]; then
        return
    fi

    if command -v mysql &> /dev/null; then
        DB_TYPE="mysql"
        print_info "Detected: MySQL/MariaDB"
    elif command -v psql &> /dev/null; then
        DB_TYPE="postgresql"
        print_info "Detected: PostgreSQL"
    else
        print_error "No database found. Install MySQL or PostgreSQL first."
        exit 1
    fi
}

#######################################
# MySQL: Analyze
#######################################
mysql_analyze() {
    local database="${1:-}"

    print_info "Analyzing MySQL performance..."

    # Database size
    print_info "Database sizes:"
    mysql -e "SELECT
        table_schema AS 'Database',
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
    FROM information_schema.tables
    GROUP BY table_schema;"

    # Table sizes
    if [[ -n "$database" ]]; then
        print_info "Table sizes in '$database':"
        mysql -e "SELECT
            table_name AS 'Table',
            ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
        FROM information_schema.tables
        WHERE table_schema = '$database'
        ORDER BY (data_length + index_length) DESC
        LIMIT 20;"
    fi

    # InnoDB status
    print_info "InnoDB buffer pool usage:"
    mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 10 "BUFFER POOL"
}

#######################################
# MySQL: Optimize
#######################################
mysql_optimize() {
    local database="${1:-}"

    if [[ -z "$database" ]]; then
        print_error "Database name required for optimization"
        exit 1
    fi

    print_info "Optimizing tables in '$database'..."

    local tables
    tables=$(mysql -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema='$database';")

    for table in $tables; do
        print_info "Optimizing: $table"
        if [[ "$DRY_RUN" == "false" ]]; then
            mysql -e "OPTIMIZE TABLE $database.$table;"
        else
            print_warning "[DRY-RUN] Would optimize: $database.$table"
        fi
    done

    print_success "Optimization complete"
}

#######################################
# MySQL: Slow queries
#######################################
mysql_slow_queries() {
    print_info "Slow queries (last 100):"

    mysql -e "SELECT
        query_time,
        lock_time,
        rows_examined,
        sql_text
    FROM mysql.slow_log
    ORDER BY query_time DESC
    LIMIT 100;" 2>/dev/null || print_warning "Slow query log not enabled"

    print_info "To enable slow query log:"
    echo "  SET GLOBAL slow_query_log = 'ON';"
    echo "  SET GLOBAL long_query_time = 2;"
}

#######################################
# MySQL: Connections
#######################################
mysql_connections() {
    print_info "Active connections:"

    mysql -e "SHOW PROCESSLIST;"

    echo ""
    print_info "Connection statistics:"
    mysql -e "SHOW STATUS LIKE 'Threads_%';"
    mysql -e "SHOW STATUS LIKE 'Max_used_connections';"
    mysql -e "SHOW VARIABLES LIKE 'max_connections';"
}

#######################################
# MySQL: Stats
#######################################
mysql_stats() {
    print_info "MySQL Statistics:"

    echo ""
    echo "=== Uptime ==="
    mysql -e "SHOW STATUS LIKE 'Uptime';"

    echo ""
    echo "=== Queries ==="
    mysql -e "SHOW STATUS LIKE 'Questions';"
    mysql -e "SHOW STATUS LIKE 'Queries';"

    echo ""
    echo "=== InnoDB ==="
    mysql -e "SHOW STATUS LIKE 'Innodb_buffer_pool%';"

    echo ""
    echo "=== Connections ==="
    mysql -e "SHOW STATUS LIKE 'Connections';"
    mysql -e "SHOW STATUS LIKE 'Max_used_connections';"
}

#######################################
# PostgreSQL: Analyze
#######################################
pg_analyze() {
    print_info "Analyzing PostgreSQL performance..."

    sudo -u postgres psql -c "
        SELECT
            datname AS database,
            pg_size_pretty(pg_database_size(datname)) AS size
        FROM pg_database
        WHERE datistemplate = false
        ORDER BY pg_database_size(datname) DESC;"

    print_info "Largest tables:"
    sudo -u postgres psql -c "
        SELECT
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
        FROM pg_tables
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT 20;"
}

#######################################
# PostgreSQL: Vacuum
#######################################
pg_vacuum() {
    local database="${1:-}"

    if [[ -z "$database" ]]; then
        print_info "Vacuuming all databases..."
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo -u postgres vacuumdb --all --analyze
        else
            print_warning "[DRY-RUN] Would vacuum all databases"
        fi
    else
        print_info "Vacuuming database: $database"
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo -u postgres vacuumdb --analyze "$database"
        else
            print_warning "[DRY-RUN] Would vacuum: $database"
        fi
    fi

    print_success "Vacuum complete"
}

#######################################
# PostgreSQL: Connections
#######################################
pg_connections() {
    print_info "Active connections:"

    sudo -u postgres psql -c "
        SELECT
            pid,
            usename,
            application_name,
            client_addr,
            state,
            query
        FROM pg_stat_activity
        WHERE state != 'idle'
        ORDER BY pid;"

    echo ""
    print_info "Connection statistics:"
    sudo -u postgres psql -c "
        SELECT
            count(*),
            state
        FROM pg_stat_activity
        GROUP BY state;"
}

#######################################
# PostgreSQL: Stats
#######################################
pg_stats() {
    print_info "PostgreSQL Statistics:"

    echo ""
    echo "=== Database Activity ==="
    sudo -u postgres psql -c "
        SELECT
            datname,
            numbackends AS connections,
            xact_commit AS commits,
            xact_rollback AS rollbacks
        FROM pg_stat_database;"

    echo ""
    echo "=== Cache Hit Ratio ==="
    sudo -u postgres psql -c "
        SELECT
            sum(heap_blks_read) as heap_read,
            sum(heap_blks_hit) as heap_hit,
            sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
        FROM pg_statio_user_tables;"
}

#######################################
# Main function
#######################################
main() {
    local command="${1:-}"
    local database=""

    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi

    shift

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                DB_TYPE="$2"
                shift 2
                ;;
            --database)
                database="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Detect database if not specified
    detect_db_type

    # Execute command
    case "$command" in
        analyze)
            if [[ "$DB_TYPE" == "mysql" ]]; then
                mysql_analyze "$database"
            else
                pg_analyze
            fi
            ;;
        optimize)
            if [[ "$DB_TYPE" == "mysql" ]]; then
                mysql_optimize "$database"
            else
                print_error "Use 'vacuum' command for PostgreSQL"
                exit 1
            fi
            ;;
        vacuum)
            if [[ "$DB_TYPE" == "postgresql" ]]; then
                pg_vacuum "$database"
            else
                print_error "Vacuum is for PostgreSQL only"
                exit 1
            fi
            ;;
        slow-queries)
            if [[ "$DB_TYPE" == "mysql" ]]; then
                mysql_slow_queries
            else
                print_error "Not implemented for PostgreSQL yet"
                exit 1
            fi
            ;;
        connections)
            if [[ "$DB_TYPE" == "mysql" ]]; then
                mysql_connections
            else
                pg_connections
            fi
            ;;
        stats)
            if [[ "$DB_TYPE" == "mysql" ]]; then
                mysql_stats
            else
                pg_stats
            fi
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
