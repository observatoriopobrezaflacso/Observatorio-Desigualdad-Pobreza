import pandas as pd

file_path = r'c:\Observatorio\Observatorio-Desigualdad-Pobreza\Dashboards\Data 2\base_1.xlsx'

try:
    xls = pd.ExcelFile(file_path)
    print("Sheet names found:")
    for sheet in xls.sheet_names:
        print(f"- {sheet}")
except Exception as e:
    print(f"Error reading excel file: {e}")
