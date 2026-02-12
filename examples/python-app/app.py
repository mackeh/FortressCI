from flask import Flask, request, render_template_string
import sqlite3
import os

app = Flask(__name__)

# INTENTIONAL VULNERABILITY: Hardcoded Secret
DB_PASSWORD = "super-secret-password-123"

@app.route("/")
def index():
    return "FortressCI Vulnerable Python App"

@app.route("/search")
def search():
    query = request.args.get('query', '')
    
    # INTENTIONAL VULNERABILITY: SQL Injection
    db = sqlite3.connect('example.db')
    cursor = db.cursor()
    cursor.execute(f"SELECT * FROM items WHERE name = '{query}'")
    results = cursor.fetchall()
    
    # INTENTIONAL VULNERABILITY: Server-Side Template Injection (SSTI)
    template = f"<h1>Search results for: {query}</h1>"
    return render_template_string(template)

if __name__ == "__main__":
    app.run(debug=True) # INTENTIONAL VULNERABILITY: Debug mode enabled
