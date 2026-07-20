import pandas as pd
from sklearn.linear_model import LinearRegression
from database import get_db_connection

def calculate_edc():
    # 1. Pull historical dwell times per office
    # This query calculates the average time (in hours) a document spends at each office
    dwell_query = """
        SELECT current_office_id, AVG(EXTRACT(EPOCH FROM (time_out - time_in))/3600) as avg_hours
        FROM public.processed_document
        WHERE time_in IS NOT NULL AND time_out IS NOT NULL
        GROUP BY current_office_id;
    """
    
    with get_db_connection() as conn:
        dwell_df = pd.read_sql_query(dwell_query, conn)
    
    # Create a dictionary for quick lookup: {office_id: avg_hours}
    dwell_map = dict(zip(dwell_df['current_office_id'], dwell_df['avg_hours']))
    
    # 2. Return a prediction based on actual historical data per office
    # If a specific office hasn't been visited yet, we use a global average (e.g., 24 hours)
    global_avg = dwell_df['avg_hours'].mean() if not dwell_df.empty else 24
    
    predictions = []
    # Generate predictions for all process patterns existing in your DB
    query_processes = "SELECT p_id, stop_1, stop_2, stop_3, stop_4, stop_5, stop_6, stop_7 FROM public.process_type pt JOIN public.route r ON pt.r_id = r.r_id"
    with get_db_connection() as conn:
        processes = pd.read_sql_query(query_processes, conn)
    
    for _, proc in processes.iterrows():
        # Sum the average dwell times of all active stops in this process
        total_estimated_hours = 0
        stops = [proc['stop_1'], proc['stop_2'], proc['stop_3'], proc['stop_4'], proc['stop_5'], proc['stop_6'], proc['stop_7']]
        
        for stop_id in stops:
            if stop_id:
                total_estimated_hours += dwell_map.get(stop_id, global_avg)
                
        predictions.append({
            "process_id": int(proc['p_id']),
            "estimated_hours_to_complete": round(total_estimated_hours, 2)
        })
        
    return predictions