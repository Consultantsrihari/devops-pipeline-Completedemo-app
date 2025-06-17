const request = require('supertest');
const app = require('../app');

describe('GET /', () => {
  it('should return "Hello from DevOps Pipeline Demo App!"', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toEqual(200);
    expect(res.text).toEqual('Hello from DevOps Pipeline Demo App!');
  });
});

describe('GET /health', () => {
  it('should return "OK"', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toEqual(200);
    expect(res.text).toEqual('OK');
  });
});

// A simple test for the metrics endpoint
describe('GET /metrics', () => {
  it('should return Prometheus metrics format', async () => {
    const res = await request(app).get('/metrics');
    expect(res.statusCode).toEqual(200);
    expect(res.header['content-type']).toEqual('text/plain; charset=utf-8');
    expect(res.text).toContain('# HELP app_request_total Total number of requests.');
    expect(res.text).toContain('app_request_total ');
  });
});
