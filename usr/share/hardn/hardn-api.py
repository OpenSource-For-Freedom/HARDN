#!/usr/bin/env python3
"""
HARDN REST API Server
Provides headless API access to HARDN system information and controls
"""

import json
import subprocess
import sys
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import logging
import os
import signal
import threading
import time

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - HARDN-API - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class HARDNAPIHandler(BaseHTTPRequestHandler):
    """HTTP request handler for HARDN API"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        try:
            if path == '/':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    "status": "ok",
                    "message": "HARDN API Server",
                    "version": "2.0.0",
                    "endpoints": [
                        "/status",
                        "/audit",
                        "/version",
                        "/health"
                    ]
                }
                self.wfile.write(json.dumps(response, indent=2).encode())
                
            elif path == '/status':
                self.send_system_status()
                
            elif path == '/audit':
                self.send_audit_results()
                
            elif path == '/version':
                self.send_version()
                
            elif path == '/health':
                self.send_health_check()
                
            else:
                self.send_error(404, "Endpoint not found")
                
        except Exception as e:
            logger.error(f"Error handling request: {e}")
            self.send_error(500, f"Internal server error: {str(e)}")
    
    def send_system_status(self):
        """Send system status information"""
        try:
            # Get basic system info using hardn command
            result = subprocess.run(['hardn', 'status'], capture_output=True, text=True)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "status": "ok",
                "hardn_status": result.stdout if result.returncode == 0 else "Error getting status",
                "timestamp": time.time()
            }
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            logger.error(f"Error getting system status: {e}")
            self.send_error(500, f"Error getting system status: {str(e)}")
    
    def send_audit_results(self):
        """Send audit results"""
        try:
            # Run audit command
            result = subprocess.run(['hardn', 'audit', '--json'], capture_output=True, text=True)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            if result.returncode == 0:
                try:
                    # Try to parse as JSON
                    audit_data = json.loads(result.stdout)
                    response = {
                        "status": "ok",
                        "audit_results": audit_data,
                        "timestamp": time.time()
                    }
                except json.JSONDecodeError:
                    # If not JSON, wrap in text response
                    response = {
                        "status": "ok",
                        "audit_results": {"output": result.stdout},
                        "timestamp": time.time()
                    }
            else:
                response = {
                    "status": "error",
                    "message": "Audit command failed",
                    "error": result.stderr,
                    "timestamp": time.time()
                }
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            logger.error(f"Error running audit: {e}")
            self.send_error(500, f"Error running audit: {str(e)}")
    
    def send_version(self):
        """Send version information"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        response = {
            "status": "ok",
            "version": "2.0.0",
            "name": "HARDN",
            "description": "Linux Security Hardening Sentinel",
            "timestamp": time.time()
        }
        
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def send_health_check(self):
        """Send health check response"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        response = {
            "status": "ok",
            "health": "healthy",
            "timestamp": time.time()
        }
        
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def log_message(self, format, *args):
        """Custom log message handler"""
        logger.info(f"{self.address_string()} - {format % args}")

class HARDNAPIServer:
    """HARDN API Server"""
    
    def __init__(self, host='localhost', port=8080):
        self.host = host
        self.port = port
        self.server = None
        self.running = False
    
    def start(self):
        """Start the API server"""
        try:
            self.server = HTTPServer((self.host, self.port), HARDNAPIHandler)
            self.running = True
            
            logger.info(f"HARDN API Server starting on {self.host}:{self.port}")
            logger.info("Press Ctrl+C to stop the server")
            
            # Handle shutdown signals
            signal.signal(signal.SIGINT, self._signal_handler)
            signal.signal(signal.SIGTERM, self._signal_handler)
            
            self.server.serve_forever()
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            sys.exit(1)
    
    def stop(self):
        """Stop the API server"""
        if self.server and self.running:
            logger.info("Stopping HARDN API Server...")
            self.server.shutdown()
            self.server.server_close()
            self.running = False
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.stop()

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='HARDN REST API Server')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to (default: 8080)')
    parser.add_argument('--version', action='version', version='HARDN API Server 2.0.0')
    
    args = parser.parse_args()
    
    # Check if running as root (required for some hardn commands)
    if os.geteuid() != 0:
        logger.warning("Running as non-root user. Some functionality may be limited.")
    
    # Start the server
    server = HARDNAPIServer(args.host, args.port)
    server.start()

if __name__ == '__main__':
    main()
