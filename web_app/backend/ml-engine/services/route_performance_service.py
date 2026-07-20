import pandas as pd
from database import get_db_connection

def calculate_document_routing_efficiency():
    """
    Evaluates routing efficiency by calculating the average completion time 
    for documents passing through their assigned process routes.
    """
    query = """
        SELECT 
            pt.process_name AS route_name,
            AVG(EXTRACT(EPOCH FROM (pd.time_out - pd.time_in))) AS avg_processing_seconds
        FROM public.processed_document pd
        JOIN public.initial_document id ON pd.ini_id = id.ini_id
        JOIN public.process_type pt ON id.p_id = pt.p_id
        WHERE pd.time_in IS NOT NULL AND pd.time_out IS NOT NULL
        GROUP BY pt.process_name;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty:
        return []
        
    # Convert extracted seconds into hours for frontend consumption
    df['avg_completion_hours'] = (df['avg_processing_seconds'] / 3600).round(2)
    
    return df[['route_name', 'avg_completion_hours']].to_dict(orient='records')


def calculate_vehicle_scheduling_performance():
    """
    Measures turnaround time and efficiency strictly for targeted 
    vehicle scheduling across the university fleet.
    """
    # NOTE: Ensure 'public.assets' matches your actual NeonDB table name!
    query = """
        SELECT 
            a.asset_name,
            COUNT(v.v_id) AS total_trips,
            AVG(EXTRACT(EPOCH FROM (v.drop_off_time - v.pick_up_time))) AS avg_trip_seconds
        FROM public.vehicle_requirements v
        JOIN public.asset_details a ON v.asd_id = a.asd_id
        GROUP BY a.asset_name;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty:
        return []
        
    # Convert seconds to hours for turnaround metric
    df['avg_turnaround_hours'] = (df['avg_trip_seconds'] / 3600).round(2)
    
    # Extract the raw dictionary
    records = df[['asset_name', 'total_trips', 'avg_turnaround_hours']].to_dict(orient='records')
    
    # Clean the payload to prevent FastAPI 500 JSON serialization errors
    cleaned_records = [
        {
            "asset_name": str(row["asset_name"]), 
            "total_trips": int(row["total_trips"]), 
            "avg_turnaround_hours": float(row["avg_turnaround_hours"])
        } 
        for row in records
    ]
    
    return cleaned_records