import os
import psycopg


def main() -> None:
    host = os.getenv("PGHOST", "db")
    port = os.getenv("PGPORT", "5432")
    user = os.getenv("PGUSER", "postgres")
    password = os.getenv("PGPASSWORD", "postgres")
    target_db = os.getenv("PGDATABASE", "ecommerce")

    with psycopg.connect(
        host=host,
        port=port,
        dbname="postgres",
        user=user,
        password=password,
        autocommit=True,
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (target_db,))
            exists = cur.fetchone() is not None
            if not exists:
                cur.execute(f'CREATE DATABASE "{target_db}"')
                print(f"Database created: {target_db}")
            else:
                print(f"Database already exists: {target_db}")


if __name__ == "__main__":
    main()