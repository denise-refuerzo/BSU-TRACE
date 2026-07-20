import pandas as pd
from database import get_db_connection

def calculate_office_dwell_times():
    """
    Queries historical tracking data and runs an analytical evaluation process 
    to group and rank average office dwell times. 
    """
    query = """
        SELECT 
            off.office_name,
            pdoc.time_in,
            pdoc.time_out,
            EXTRACT(EPOCH FROM (pdoc.time_out - pdoc.time_in))/3600 as dwell_time_hours
        FROM public.processed_document pdoc
        JOIN public.offices off ON pdoc.current_office_id = off.o_id
        WHERE pdoc.time_in IS NOT NULL 
          AND pdoc.time_out IS NOT NULL;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty:
        return []
        
    # Aggregate data: Calculate the mean dwell time per office hierarchy node
    heatmap_data = df.groupby('office_name')['dwell_time_hours'].mean().reset_index()
    
    # Sort to surface the highest stagnation offices at the top
    heatmap_data = heatmap_data.sort_values(by='dwell_time_hours', ascending=False)
    
    return heatmap_data.to_dict(orient='records')