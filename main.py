import sqlite3

# Path to your SQLite .db file
db_path = r"C:\Users\3beda\OneDrive\Desktop\GitProjects\FootballAnalysisProject\football.db"

# Connect to the database
conn = sqlite3.connect(db_path)

# Create a cursor to execute SQL queries
cursor = conn.cursor()

# Example: fetch data
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()

print("Tables:", tables)

# Always close connection
conn.close()

