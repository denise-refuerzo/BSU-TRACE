import pandas as pd
from sklearn.linear_model import LinearRegression
from database import get_db_connection

def calculate_edc():
    """
    Trains a Linear Regression model on historical document completion times 
    to forecast the Estimated Date of Completion for pending paperwork.
    """
    # 1. Pull historical data: We need documents that have fully completed their routing
    query = """
        SELECT 
            i.qr_code,
            COUNT(p.pd_id) as total_steps,
            EXTRACT(EPOCH FROM (MAX(p.time_out) - MIN(p.time_in)))/3600 as total_hours_taken
        FROM public.processed_document p
        JOIN public.initial_document i ON p.ini_id = i.ini_id
        WHERE p.time_in IS NOT NULL AND p.time_out IS NOT NULL
        GROUP BY i.qr_code
        HAVING EXTRACT(EPOCH FROM (MAX(p.time_out) - MIN(p.time_in))) > 0;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty or len(df) < 5:
        return {"message": "Not enough historical data to train the EDC model."}
        
    # 2. Define Features (X) and Target (y)
    # X = Total steps/offices required for the document
    # y = Total hours it historically took to complete
    X = df[['total_steps']] 
    y = df['total_hours_taken']
    
    # 3. Train the Linear Regression Model
    model = LinearRegression()
    model.fit(X, y)
    
    # 4. Generate a baseline prediction matrix for the frontend
    # Example: Predicting time for documents requiring 1 to 10 steps
    predictions = []
    for steps in range(1, 11):
        predicted_hours = model.predict([[steps]])[0]
        predictions.append({
            "required_offices": steps,
            "estimated_hours_to_complete": round(predicted_hours, 2)
        })
        
    return predictions