#!/bin/sh
if [ "$MODE" = "worker" ]; then
  # Start worker process in the background
  echo "Starting worker process in background..."
  pnpm start-worker &
  WORKER_PID=$!
  echo "Worker process started with PID: $WORKER_PID"

  # Export WORKER_PID for the health check server
  export WORKER_PID
  
  # Start a sidecar health check server
  echo "Starting health check server..."
  WORKER_PID=$WORKER_PID node -e "
    const http = require('http');
    const fs = require('fs');

    const workerPid = process.env.WORKER_PID;

    const server = http.createServer((req, res) => {
      if (req.url === '/health' || req.url === '/') {
        // Check if the worker process is still running by checking the PID
        if (workerPid) {
          fs.stat('/proc/' + workerPid, (err) => {
            if (err) {
              // If err is not null, the process directory doesn't exist, so the process is dead
              res.writeHead(503, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ status: 'unhealthy', reason: 'Worker process PID ' + workerPid + ' not found' }));
            } else {
              res.writeHead(200, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ status: 'healthy' }));
            }
          });
        } else {
          res.writeHead(503, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'unhealthy', reason: 'Worker PID not set' }));
        }
      } else {
        res.writeHead(404);
        res.end('Not Found');
      }
    });

    const port = process.env.PORT || 3000;
    server.listen(port, () => {
      console.log('Health server listening on port ' + port + ' for worker PID ' + workerPid);
    });

    // Gracefully handle termination signals
    const shutdown = (signal) => {
      console.log('Health server received ' + signal + ', shutting down.');
      server.close(() => {
        console.log('Health server closed.');
        // Kill the worker process when the health check server is terminated
        if (workerPid) {
          try {
            console.log('Killing worker process PID ' + workerPid);
            process.kill(parseInt(workerPid), signal);
          } catch (e) {
            console.error('Could not kill worker process ' + workerPid + ':', e.message);
          }
        }
        process.exit(0);
      });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  " &
  
  # Wait for both processes to keep the container running
  wait
else
  # Start normal server
  pnpm start
fi
