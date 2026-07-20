from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from services.bottleneck_service import calculate_office_dwell_times
from services.edc_service import calculate_edc
from services.peak_demand_service import calculate_peak_demand


app = FastAPI(title="BSU-Trace Analytics Engine")

# Configure CORS so your React UI and Flutter app can securely poll data
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/analytics/bottlenecks")
def get_bottlenecks():
    """Endpoint serving descriptive bottleneck analytics for heatmap rendering."""
    try:
        data = calculate_office_dwell_times()
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analytical engine error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

# Add this endpoint below your bottleneck route
@app.get("/api/analytics/edc")
def get_edc_forecasts():
    """Endpoint serving Linear Regression EDC forecasts."""
    try:
        data = calculate_edc()
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"EDC engine error: {str(e)}")

@app.get("/api/analytics/peak-demand")
def get_peak_demand_forecast():
    """Endpoint serving Holt-Winters time-series forecasts for resource scheduling."""
    try:
        data = calculate_peak_demand()
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Forecasting engine error: {str(e)}")