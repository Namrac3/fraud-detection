# Fraud Detection SQL Server Project

This project sets up a SQL Server database for fraud detection and includes:
- Schema creation scripts
- Seed data scripts
- Test queries for validation
- GitHub Actions CI workflow for automated testing

## Project Structure
```
fraud-detection-sql-server/
│── sql/
│   ├── schema.sql         # Database schema creation
│   ├── seed.sql           # Initial data load
│   └── tests.sql          # Validation test queries
│── .github/
│   └── workflows/
│       └── ci.yml         # GitHub Actions workflow
│── README.md              # Project documentation
```

## Running Locally
1. Start a SQL Server instance (Docker recommended):
   ```bash
   docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Your_password123" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2019-latest
   ```

2. Run schema and seed scripts:
   ```bash
   docker exec -i <container_id> /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Your_password123" -d master -i /sql/schema.sql
   docker exec -i <container_id> /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Your_password123" -d master -i /sql/seed.sql
   ```

3. Run tests:
   ```bash
   docker exec -i <container_id> /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Your_password123" -d master -i /sql/tests.sql
   ```

## GitHub Actions CI/CD
The pipeline will:
1. Spin up SQL Server 2019 in Docker
2. Run schema and seed scripts
3. Execute tests
4. Upload logs as artifacts

## Notes
- Default SA password in CI is `Your_password123`.
- Update workflow if you need a stronger password or secrets.
