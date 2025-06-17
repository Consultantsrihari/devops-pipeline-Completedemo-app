const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

let requestCount = 0;

app.get('/', (req, res) => {
    requestCount++;
    res.send('Hello from DevOps Pipeline Demo App!');
});

app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// Basic custom metrics endpoint for Prometheus
app.get('/metrics', (req, res) => {
    res.set('Content-Type', 'text/plain');
    res.end(`# HELP app_request_total Total number of requests.
# TYPE app_request_total counter
app_request_total ${requestCount}
`);
});

app.listen(port, () => {
    console.log(`DevOps Demo App listening on port ${port}`);
});

module.exports = app; // For testing
