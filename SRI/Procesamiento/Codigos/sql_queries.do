python set exec "C:\Users\vero\AppData\Local\Programs\Python\Python313\python.exe"

python:
import duckdb
print(duckdb.connect().execute("SELECT 10+5").fetchall())
end


python:
import duckdb

con = duckdb.connect(
    r"G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Observatorio GH\Boletín 2\Procesamiento\Bases\Censo\mydb.duckdb"
)

print(
    con.execute("DESCRIBE censo2022").fetchdf()
)
end


python:
import duckdb

con = duckdb.connect(
    r"G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Observatorio GH\Boletín 2\Procesamiento\Bases\Censo\mydb.duckdb"
)

print(
    con.execute("""
        SELECT COUNT(*) AS total_personas
        FROM censo2022
    """).fetchdf()
)
end



python:
import duckdb

con = duckdb.connect(
    r"G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Observatorio GH\Boletín 2\Procesamiento\Bases\Censo\mydb.duckdb"
)

print(
    con.execute("""
        SELECT I03, COUNT(*) AS n
        FROM censo2022
        GROUP BY I03
        ORDER BY I03
    """).fetchdf()
)
end



python:
import sys
print(sys.executable)
end

python:
import duckdb
from pystata import stata

# Connect to DuckDB
con = duckdb.connect(
    r"G:\Mi unidad\Trabajos\Observatorio de Políticas Públicas\Observatorio GH\Boletín 2\Procesamiento\Bases\Censo\mydb.duckdb"
)

# SQL query (keep only I02 == 1)
df = con.execute("""
    SELECT
        I01 AS provincia,
        COUNT(*) AS poblacion_urbana
    FROM censo2022
    WHERE I02 = 1
    GROUP BY I01
    ORDER BY poblacion_urbana DESC
""").fetchdf()

# Send result to Stata
stata.pdataframe_to_data(df, force=True)

end


