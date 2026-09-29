import express from "express";

const GREETING = "hello v1"; // the demo edits this line

const app = express();
app.get("/", (_req, res) => { res.json({ greeting: GREETING }); });
app.get("/healthz", (_req, res) => { res.send("ok"); });

const server = app.listen(3000, () => console.log("listening on 3000"));

process.on("SIGTERM", () => {
  // stop accepting, let in-flight requests finish
  server.close(() => process.exit(0));
  // give up before the platform's SIGKILL
  setTimeout(() => process.exit(1), 25_000).unref();
});
