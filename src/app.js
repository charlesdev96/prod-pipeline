const http = require("http");

const VERSION = process.env.APP_VERSION || "dev";

function sendJson(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

function handleRequest(req, res) {
  if (req.url === "/health") {
    sendJson(res, 200, { status: "ok" });
  } else if (req.url === "/") {
    sendJson(res, 200, {
      message: "Hello from the CI/CD pipeline",
      version: VERSION,
    });
  } else {
    sendJson(res, 404, { error: "not found" });
  }
}

const server = http.createServer(handleRequest);

module.exports = server;
