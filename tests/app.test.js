const request = require("supertest");
const server = require("../src/app");

describe("app", () => {
  test("GET /health returns ok", async () => {
    const res = await request(server).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
  });

  test("GET / returns a message and a version", async () => {
    const res = await request(server).get("/");
    expect(res.status).toBe(200);
    expect(res.body.message).toBe("Hello from the CI/CD pipeline");
    expect(res.body.version).toBeDefined();
  });

  test("unknown path returns 404", async () => {
    const res = await request(server).get("/nope");
    expect(res.status).toBe(404);
  });
});
