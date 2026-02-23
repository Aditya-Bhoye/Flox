from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import pandas as pd
import numpy as np
import os

app = FastAPI()

# Load the model
MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "loan_model_top6.pkl")

try:
    model = joblib.load(MODEL_PATH)
    print(f"Model loaded successfully from {MODEL_PATH}")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

class LoanApplication(BaseModel):
    cibil_score: int
    loan_term: int
    loan_amount: int
    income_annum: int
    bank_asset_value: int
    residential_assets_value: int

@app.get("/")
def read_root():
    return {"message": "Loan Approval Prediction API"}

@app.post("/predict")
def predict_loan(application: LoanApplication):
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    # Prepare input data as a DataFrame with the same column names as used during training
    # Based on the notebook, the selected features were:
    # "cibil_score", "loan_term", "loan_amount", "income_annum", "bank_asset_value", "residential_assets_value"
    
    input_data = pd.DataFrame([{
        "cibil_score": application.cibil_score,
        "loan_term": application.loan_term,
        "loan_amount": application.loan_amount,
        "income_annum": application.income_annum,
        "bank_asset_value": application.bank_asset_value,
        "residential_assets_value": application.residential_assets_value
    }])
    
    try:
        prediction = model.predict(input_data)
        # Prediction is 1 for Approved, 0 for Rejected
        result = "Approved" if prediction[0] == 1 else "Rejected"
        return {"prediction": result, "status_code": int(prediction[0])}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
