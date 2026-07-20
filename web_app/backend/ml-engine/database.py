import psycopg2
from contextlib import contextmanager
from config import settings

@contextmanager
def get_db_connection():
    """Context manager to ensure database connections are cleaned up safely."""
    conn = psycopg2.connect(settings.ML_DATABASE_URL)
    try:
        yield conn
    finally:
        conn.close()