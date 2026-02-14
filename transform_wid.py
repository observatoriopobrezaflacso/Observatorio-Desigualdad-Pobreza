import pandas as pd
import sys

file_path = r'c:\Observatorio\Observatorio-Desigualdad-Pobreza\Dashboards\Data 2\base_1.xlsx'
sheet_name = 'WID_INGRESO'

try:
    print(f"Reading {sheet_name} from {file_path}...")
    df = pd.read_excel(file_path, sheet_name=sheet_name)
    
    # Identify columns by position as requested (B and C are indices 1 and 2)
    # A is index 0 (Year/Ao) behavior
    id_vars = [df.columns[0]]
    value_vars = [df.columns[1], df.columns[2]]
    
    print(f"Merging columns: {value_vars}")
    
    # Melt
    df_melted = df.melt(id_vars=id_vars, value_vars=value_vars, 
                        var_name='Indicador', value_name='Valor')
    
    print("Transformed data preview:")
    print(df_melted.head())
    
    # Write back
    print("Saving changes...")
    with pd.ExcelWriter(file_path, engine='openpyxl', mode='a', if_sheet_exists='replace') as writer:
        df_melted.to_excel(writer, sheet_name=sheet_name, index=False)
        
    print("Successfully saved changes to base_1.xlsx")

except Exception as e:
    print(f"Error during transformation: {e}")
    sys.exit(1)
