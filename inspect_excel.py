import pandas as pd

file_path = r'c:\Observatorio\Observatorio-Desigualdad-Pobreza\Dashboards\Data 2\base_1.xlsx'
sheet_name = 'WID_INGRESO'

try:
    # Read the first few rows to understand the structure
    df = pd.read_excel(file_path, sheet_name=sheet_name, nrows=5)
    print("Columns:")
    print(df.columns.tolist())
    print("\nFirst 5 rows:")
    print(df.head())
    print("\nColumns B and C data:")
    # Assuming columns are 0-indexed, B is 1, C is 2
    # But let's print by name if possible, or index
    col_b = df.columns[1]
    col_c = df.columns[2]
    print(f"Column B name: {col_b}")
    print(f"Column C name: {col_c}")
    print(df.iloc[:, 1:3].head())
except Exception as e:
    print(f"Error reading excel: {e}")
