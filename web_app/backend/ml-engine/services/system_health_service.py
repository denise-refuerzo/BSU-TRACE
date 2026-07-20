import pandas as pd
from database import get_db_connection

def get_database_status():
    """
    Pings the PostgreSQL database to ensure active connections are healthy.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return "HEALTHY"
    except Exception:
        return "DISCONNECTED"

def run_data_quality_audit():
    """
    Executes automated checks to verify null value constraints 
    and identify missing timestamps within processed documents.
    """
    query = """
        SELECT 
            COUNT(*) AS total_documents,
            COUNT(CASE WHEN time_in IS NULL THEN 1 END) AS missing_time_in_records,
            COUNT(CASE WHEN time_out IS NULL THEN 1 END) AS missing_time_out_records
        FROM public.processed_document;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty:
        return {
            "status": "PASS", 
            "integrity_score_percentage": 100.0, 
            "audit_details": {}
        }
        
    total_documents = int(df['total_documents'].iloc[0])
    missing_time_in = int(df['missing_time_in_records'].iloc[0])
    missing_time_out = int(df['missing_time_out_records'].iloc[0])
    
    if total_documents == 0:
        integrity_score = 100.0
    else:
        invalid_docs = missing_time_in + missing_time_out
        integrity_score = ((total_documents - invalid_docs) / total_documents) * 100.0
        
    return {
        "status": "PASS" if integrity_score >= 95.0 else "WARNING",
        "integrity_score_percentage": round(integrity_score, 2),
        "audit_details": {
            "missing_time_in_records": missing_time_in,
            "missing_time_out_records": missing_time_out,
            "total_records_scanned": total_documents
        }
    }

def get_system_health_metrics():
    """
    Aggregates database connectivity and data quality audit results.
    """
    return {
        "database_connection": get_database_status(),
        "data_quality_audit": run_data_quality_audit()
    }