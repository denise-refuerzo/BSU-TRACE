import pandas as pd
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from database import get_db_connection
import warnings
from statsmodels.tools.sm_exceptions import ConvergenceWarning

# Suppress harmless convergence warnings to keep your terminal clean
warnings.simplefilter('ignore', ConvergenceWarning)

def calculate_peak_demand():
    """
    Trains Holt-Winters Exponential Smoothing models on daily historical 
    booking data to forecast future resource demand for the next 30 days.
    """
    # 1. Pull historical daily reservations split by booking type
    query = """
        SELECT 
            reservation_date, 
            booking_type,
            COUNT(booking_id) as daily_demand
        FROM public.bookings
        WHERE status = 'Confirmed'
        GROUP BY reservation_date, booking_type
        ORDER BY reservation_date;
    """
    
    with get_db_connection() as conn:
        df = pd.read_sql_query(query, conn)
        
    if df.empty or len(df) < 14:
        return {"message": "Not enough historical data. At least 14 days of confirmed bookings are required to train the forecast."}
        
    # 2. Prepare the Time Series Data
    df['reservation_date'] = pd.to_datetime(df['reservation_date'])
    
    # Categorize bookings (Groups Rooms and Gyms as facilities, Vehicles as vehicles)
    df['category'] = df['booking_type'].apply(lambda x: 'vehicle_demand' if x == 'Vehicle' else 'facility_demand')
    
    # Pivot so each category has its own column based on the date
    pivot_df = df.pivot_table(index='reservation_date', columns='category', values='daily_demand', aggfunc='sum').fillna(0)
    
    # Ensure columns exist even if no historical data exists for one type yet
    for col in ['vehicle_demand', 'facility_demand']:
        if col not in pivot_df.columns:
            pivot_df[col] = 0
            
    # Resample to ensure every single calendar day is represented
    pivot_df = pivot_df.resample('D').sum().fillna(0)
    
    # 3. Train the Holt-Winters Models safely 
    def safe_forecast(series, periods=30):
        try:
            # Adding a tiny constant prevents mathematical errors in completely flat datasets
            model = ExponentialSmoothing(
                series + 0.001, 
                trend='add', 
                seasonal='add', 
                seasonal_periods=7
            ).fit(optimized=True)
            return model.forecast(periods)
        except:
            # Fallback to a flatline if the ML model fails to converge
            return pd.Series([0] * periods, index=pd.date_range(start=series.index[-1] + pd.Timedelta(days=1), periods=periods))

    # Run dual models
    vehicle_forecast = safe_forecast(pivot_df['vehicle_demand'])
    facility_forecast = safe_forecast(pivot_df['facility_demand'])
    
    # 4. Format the output for the React frontend
    historical_data = [
        {
            "date": date.strftime("%Y-%m-%d"), 
            "vehicle_demand": int(row['vehicle_demand']),
            "facility_demand": int(row['facility_demand']),
            "type": "historical"
        }
        for date, row in pivot_df.iterrows()
    ]
    
    forecast_data = [
        {
            "date": vehicle_forecast.index[i].strftime("%Y-%m-%d"), 
            # Max(0) prevents impossible negative demand forecasts
            "vehicle_demand": max(0, round(vehicle_forecast.iloc[i], 2)),
            "facility_demand": max(0, round(facility_forecast.iloc[i], 2)),
            "type": "forecast"
        }
        for i in range(30)
    ]
    
    return historical_data + forecast_data