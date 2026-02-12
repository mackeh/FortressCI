const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const app = express();
const port = 3000;

// INTENTIONAL VULNERABILITY: Hardcoded Secret
const AWS_ACCESS_KEY = "AKIAEXAMPLE123456789";
const AWS_SECRET_KEY = "EXAMPLESECRETKEY/AWS/123456789012345678";

const db = new sqlite3.Database(':memory:');

app.get('/', (req, res) => {
  res.send('FortressCI Vulnerable Node App');
});

// INTENTIONAL VULNERABILITY: SQL Injection
app.get('/user', (req, res) => {
  const userId = req.query.id;
  db.each(`SELECT name FROM users WHERE id = ${userId}`, (err, row) => {
    if (err) {
      res.status(500).send(err.message);
    } else {
      res.send(`User: ${row.name}`);
    }
  });
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
