const http = require("node:http");
const { Client } = require("pg");

async function main() {
  const db = new Client({
    host: "db",
    user: "postgres",
    password: process.env.POSTGRES_PASSWORD,
    database: "postgres",
  });
  try {
    await db.connect();
  } catch (err) {
    // Match the slide: "ECONNREFUSED 172.18.0.2:5432"
    console.error(err.address ? `${err.code} ${err.address}:${err.port}` : err.message);
    process.exit(1);
  }
  console.log("connected to Postgres");
  const server = http.createServer(async (_req, res) => {
    const { rows } = await db.query("SELECT now() AS now");
    res.end(JSON.stringify(rows[0]));
  });
  server.listen(3000, () => console.log("listening on 3000"));
  process.on("SIGTERM", () => server.close(() => db.end().then(() => process.exit(0))));
}

main();
