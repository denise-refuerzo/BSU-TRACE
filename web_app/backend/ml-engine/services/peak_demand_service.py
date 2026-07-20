import pandas as pd
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from database import get_db_connection
import warnings
from statsmodels.tools.sm_exceptions import ConvergenceWarning

# Suppress harmless convergence warnings to keep your terminal clean
warnings.simplefilter('ignore', ConvergenceWarning)

def calculate_peak_demand():
    """
    Trains a Holt-Winters Exponential Smoothing model on daily historical 
    booking data to forecast future resource demand for the next 30 days.
    """
    # 1. Pull historical daily reservations for all GSO resources (Vans, Rooms, Furniture)
    # 1. Pull historical daily reservations for all GSO resources
    query = """
        SELECT 
            reservation_date, 
            COUNT(booking_id) as daily_demand
        FROM public.bookings
        WHERE status = 'Confirmed'
        GROUP BY reservation_date
        ORDER BY reservation_date;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    # Holt-Winters needs at least 2 full seasonal cycles (14 days) to initialize properly
    if df.empty or len(df) < 14:
        return {"message": "Not enough historical data. At least 14 days of confirmed bookings are required to train the forecast."}
        
    # 2. Prepare the Time Series Data
    df['reservation_date'] = pd.to_datetime(df['reservation_date'])
    df.set_index('reservation_date', inplace=True)
    
    # Resample to ensure every single day is represented in the index. 
    # Days with no bookings are filled with 0 to prevent gaps in the time series.
    df = df.resample('D').sum().fillna(0)
    
    # 3. Train the Holt-Winters Model
    # trend='add': Assumes linear growth/decline over time
    # seasonal='add': Assumes the seasonal variations are roughly constant
    # seasonal_periods=7: Captures the 7-day weekly university cycle
    model = ExponentialSmoothing(
        df['daily_demand'], 
        trend='add', 
        seasonal='add', 
        seasonal_periods=7
    ).fit(optimized=True)
    
    # 4. Forecast the next 30 days
    forecast = model.forecast(30)
    
    # 5. Format the output for the React frontend (combining history and forecast)
    historical_data = [
        {
            "date": date.strftime("%Y-%m-%d"), 
            "demand": int(row['daily_demand']), 
            "type": "historical"
        }
        for date, row in df.iterrows()
    ]
    
    forecast_data = [
        {
            "date": date.strftime("%Y-%m-%d"), 
            # Max(0) ensures we don't predict negative demand 
            "demand": max(0, round(value, 2)), 
            "type": "forecast"
        }
        for date, value in forecast.items()
    ]
    
    return historical_data + forecast_data