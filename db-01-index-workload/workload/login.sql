-- Login: look up a user by email (expression index on lower(email))
\set cust random(1, 200000)
SELECT org_id AS org FROM users WHERE id = :cust \gset
SELECT id, org_id FROM users WHERE lower(email) = lower('User:cust@:org.example');
