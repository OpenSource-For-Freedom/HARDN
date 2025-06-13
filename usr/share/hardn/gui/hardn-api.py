#!/usr/bin/env python3
"""
HARDN-XDR REST API Server
Simple REST API for HARDN-XDR system status and control
"""

import json
import subprocess
import os
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime

# Optional imports - gracefully handle missing packages
try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False
    print("Warning: psutil not available. System metrics will be limited.")

class HardnAPIHandler(BaseHTTPRequestHandler):
    """HTTP request handler for HARDN API"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        try:
            if path == '/api/status':
                self.handle_status()
            elif path == '/api/hardn':
                self.handle_hardn_status()
            elif path == '/api/services':
                self.handle_services()
            elif path == '/api/sysctl':
                self.handle_sysctl()
            elif path == '/api/metrics':
                self.handle_metrics()
            elif path == '/api/logs':
                self.handle_logs()
            else:
                self.send_error(404, "Endpoint not found")
        except Exception as e:
            self.send_error(500, f"Internal server error: {str(e)}")
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8')
            
            if path == '/api/service':
                self.handle_service_control(post_data)
            else:
                self.send_error(404, "Endpoint not found")
        except Exception as e:
            self.send_error(500, f"Internal server error: {str(e)}")
    
    def handle_status(self):
        """Handle system status request"""
        status_data = {
            'hostname': os.uname().nodename,
            'uptime': self.get_uptime(),
            'load_average': os.getloadavg(),
            'timestamp': datetime.now().isoformat(),
            'hardn_configured': os.path.exists('/etc/hardn/hardn.conf'),
        }
        
        self.send_json_response(status_data)
    
    def handle_hardn_status(self):
        """Handle HARDN-specific status request"""
        hardn_data = self.get_hardn_status()
        self.send_json_response(hardn_data)
    
    def handle_services(self):
        """Handle services status request"""
        services = [
            'ufw',
            'fail2ban',
            'apparmor',
            'clamav-daemon',
            'ssh',
            'auditd',
            'rsyslog',
            'systemd-timesyncd',
        ]
        
        services_data = []
        
        for service in services:
            try:
                result = subprocess.run(
                    ['systemctl', 'is-active', service],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                status = 'active' if result.returncode == 0 else 'inactive'
                
                # Check if enabled
                enabled_result = subprocess.run(
                    ['systemctl', 'is-enabled', service],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                enabled = enabled_result.returncode == 0
                
                services_data.append({
                    'name': service,
                    'status': status,
                    'enabled': enabled
                })
                
            except Exception as e:
                services_data.append({
                    'name': service,
                    'status': 'unknown',
                    'enabled': False,
                    'error': str(e)
                })
        
        self.send_json_response({'services': services_data})
    
    def handle_sysctl(self):
        """Handle sysctl parameters request"""
        parameters = [
            'kernel.dmesg_restrict',
            'kernel.kptr_restrict',
            'net.ipv4.ip_forward',
            'net.ipv4.conf.all.accept_redirects',
            'net.ipv4.tcp_syncookies',
            'fs.suid_dumpable',
            'kernel.yama.ptrace_scope',
        ]
        
        sysctl_data = {}
        
        for param in parameters:
            try:
                result = subprocess.run(
                    ['sysctl', '-n', param],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    sysctl_data[param] = result.stdout.strip()
                else:
                    sysctl_data[param] = None
                    
            except Exception as e:
                sysctl_data[param] = f"error: {str(e)}"
        
        self.send_json_response({'sysctl': sysctl_data})
    
    def handle_metrics(self):
        """Handle system metrics request"""
        if not HAS_PSUTIL:
            # Fallback metrics without psutil
            metrics_data = {
                'error': 'psutil not available',
                'basic_metrics': self.get_basic_metrics(),
                'timestamp': datetime.now().isoformat()
            }
            self.send_json_response(metrics_data)
            return
            
        try:
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Memory usage
            memory = psutil.virtual_memory()
            
            # Disk usage
            disk = psutil.disk_usage('/')
            
            # Network I/O
            network = psutil.net_io_counters()
            
            metrics_data = {
                'cpu': {
                    'percent': cpu_percent,
                    'count': psutil.cpu_count()
                },
                'memory': {
                    'total': memory.total,
                    'available': memory.available,
                    'percent': memory.percent,
                    'used': memory.used
                },
                'disk': {
                    'total': disk.total,
                    'used': disk.used,
                    'free': disk.free,
                    'percent': disk.percent
                },
                'network': {
                    'bytes_sent': network.bytes_sent,
                    'bytes_recv': network.bytes_recv,
                    'packets_sent': network.packets_sent,
                    'packets_recv': network.packets_recv
                },
                'timestamp': datetime.now().isoformat()
            }
            
            self.send_json_response(metrics_data)
            
        except Exception as e:
            self.send_error(500, f"Error collecting metrics: {str(e)}")
    
    def get_basic_metrics(self):
        """Get basic metrics without psutil"""
        basic = {}
        
        try:
            # Load average
            basic['load_average'] = os.getloadavg()
            
            # Memory from /proc/meminfo
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
                mem_total = 0
                mem_available = 0
                for line in meminfo.split('\n'):
                    if line.startswith('MemTotal:'):
                        mem_total = int(line.split()[1]) * 1024  # kB to bytes
                    elif line.startswith('MemAvailable:'):
                        mem_available = int(line.split()[1]) * 1024
                
                if mem_total > 0:
                    basic['memory'] = {
                        'total': mem_total,
                        'available': mem_available,
                        'percent': ((mem_total - mem_available) / mem_total) * 100
                    }
            
            # Disk space using df
            result = subprocess.run(['df', '-B1', '/'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    fields = lines[1].split()
                    if len(fields) >= 4:
                        basic['disk'] = {
                            'total': int(fields[1]),
                            'used': int(fields[2]),
                            'available': int(fields[3])
                        }
            
        except Exception as e:
            basic['error'] = str(e)
        
        return basic
    
    def log_message(self, format, *args):
        """Override log message to reduce noise"""
        pass  # Suppress default logging
    
    def handle_logs(self):
        """Handle logs request"""
        try:
            # Read recent auth log entries
            auth_log = "/var/log/auth.log"
            logs_data = {'logs': []}
            
            if os.path.exists(auth_log):
                result = subprocess.run(
                    ['tail', '-n', '20', auth_log],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    logs_data['logs'] = result.stdout.split('\n')
            
            # Also check HARDN logs if they exist
            hardn_log = "/var/log/hardn/security.log"
            if os.path.exists(hardn_log):
                result = subprocess.run(
                    ['tail', '-n', '10', hardn_log],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    logs_data['hardn_logs'] = result.stdout.split('\n')
            
            self.send_json_response(logs_data)
            
        except Exception as e:
            self.send_error(500, f"Error reading logs: {str(e)}")
    
    def handle_service_control(self, post_data):
        """Handle service control requests"""
        try:
            data = json.loads(post_data)
            service = data.get('service')
            action = data.get('action')  # 'enable', 'disable', 'start', 'stop'
            
            if not service or not action:
                self.send_error(400, "Missing service or action parameter")
                return
            
            # Validate service name
            allowed_services = [
                'ufw', 'fail2ban', 'apparmor', 'clamav-daemon', 'ssh'
            ]
            
            if service not in allowed_services:
                self.send_error(400, f"Service {service} not allowed")
                return
            
            # Execute systemctl command
            if action in ['enable', 'disable']:
                cmd = ['sudo', 'systemctl', action, service]
            elif action in ['start', 'stop', 'restart']:
                cmd = ['sudo', 'systemctl', action, service]
            else:
                self.send_error(400, f"Unknown action: {action}")
                return
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            response_data = {
                'service': service,
                'action': action,
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }
            
            self.send_json_response(response_data)
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON data")
        except Exception as e:
            self.send_error(500, f"Error controlling service: {str(e)}")
    
    def send_json_response(self, data):
        """Send JSON response"""
        json_data = json.dumps(data, indent=2)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(json_data)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json_data.encode('utf-8'))
    
    def get_hardn_status(self):
        """Get HARDN-specific status using existing status module"""
        try:
            # Use existing status module if available
            status_module = f"{HARDN_MODULES_DIR}/status.sh"
            if os.path.exists(status_module):
                # Call the status function via hardn command
                env = os.environ.copy()
                env.update({
                    'HARDN_MODULES_DIR': HARDN_MODULES_DIR,
                    'HARDN_LOG_DIR': HARDN_LOG_DIR,
                    'HARDN_CONFIG_DIR': HARDN_CONFIG_DIR
                })
                
                result = subprocess.run(
                    ['/bin/bash', '-c', f'source {status_module} && show_hardening_status'],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    env=env
                )
                
                if result.returncode == 0:
                    return {
                        'hardn_status': 'available',
                        'output': result.stdout.split('\n')[:10],  # First 10 lines
                        'configured': True
                    }
                else:
                    return {
                        'hardn_status': 'error',
                        'error': result.stderr,
                        'configured': False
                    }
            else:
                return {
                    'hardn_status': 'not_installed',
                    'configured': False
                }
                
        except Exception as e:
            return {
                'hardn_status': 'error',
                'error': str(e),
                'configured': False
            }
    
    def get_uptime(self):
        """Get system uptime"""
        try:
            result = subprocess.run(
                ['uptime', '-p'],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout.strip() if result.returncode == 0 else "unknown"
        except:
            return "unknown"

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='HARDN-XDR REST API Server')
    parser.add_argument('--host', default='127.0.0.1', 
                       help='Host to bind to (default: 127.0.0.1)')
    parser.add_argument('--port', type=int, default=8080,
                       help='Port to bind to (default: 8080)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose logging')
    
    args = parser.parse_args()
    
    # Check if running as root
    if os.geteuid() != 0:
        print("Warning: Some features require root privileges")
        print("Consider running with sudo for full functionality")
    
    server_address = (args.host, args.port)
    httpd = HTTPServer(server_address, HardnAPIHandler)
    
    print(f"Starting HARDN-XDR API server on {args.host}:{args.port}")
    print("Available endpoints:")
    print("  GET  /api/status    - System status")
    print("  GET  /api/hardn     - HARDN-specific status")
    print("  GET  /api/services  - Services status")
    print("  GET  /api/sysctl    - Kernel parameters")
    print("  GET  /api/metrics   - System metrics")
    print("  GET  /api/logs      - Security logs")
    print("  POST /api/service   - Control services")
    print("\nPress Ctrl+C to stop the server")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down API server...")
        httpd.shutdown()

if __name__ == "__main__":
    main()