# Flox

A Flutter app splits group expenses and predicts loan approval.

## Features

- **Split expenses.** Pick people from your phone contacts and split a bill with them.
- **Track debts.** See who owes you and whom you owe, and settle an amount.
- **Loan approval check.** Enter six details and a machine learning model predicts "Approved" or "Rejected".
- **Google sign-in.** Accounts and data live in Supabase.

## How the loan check works

1. The app sends six values to a FastAPI server: CIBIL score, loan term, loan amount, annual income, bank assets and residential assets.
2. The server loads a trained XGBoost classifier from `loan_model_top6.pkl`.
3. It returns the prediction to the app.

`LoanApproval.ipynb` holds the training: data cleaning, feature selection down to the top six features, and model evaluation.

## Project layout

| Path | What it holds |
|---|---|
| `mobile_app/` | The Flutter app |
| `backend/main.py` | The FastAPI prediction server |
| `loan_model_top6.pkl` | The trained model |
| `LoanApproval.ipynb` | Training notebook |

## Run

Start the backend:

```bash
cd backend
pip install -r requirements.txt
python main.py
```

The server listens on port 8000.

Then run the app:

```bash
cd mobile_app
flutter pub get
flutter run
```

On the Android emulator the app reaches the server at `10.0.2.2:8000`. On web and desktop it uses `localhost:8000`.

## Stack

Flutter · Dart · Supabase · Python · FastAPI · XGBoost · scikit-learn · pandas
