#!/usr/bin/env python3
"""
HARDN-XDR GTK Dashboard
A GTK-based GUI dashboard for HARDN-XDR security monitoring and management.
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GObject, GLib, Pango
import subprocess
import json
import time
import threading
import os
import sys
import re
import psutil
import matplotlib.pyplot as plt
from matplotlib.backends.backend_gtk3agg import FigureCanvasGTK3Agg as FigureCanvas
from matplotlib.figure import Figure
import requests
from datetime import datetime
import signal

# Constants
HARDN_MODULES_DIR = "/usr/share/hardn/modules"
HARDN_LOG_DIR = "/var/log/hardn"
HARDN_CONFIG_DIR = "/etc/hardn"

# Debian color scheme
COLORS = {
    'bg_primary': '#2E3440',      # Dark slate grey
    'bg_secondary': '#3B4252',    # Lighter slate grey
    'bg_tertiary': '#434C5E',     # Medium grey
    'text_primary': '#ECEFF4',    # Light text
    'text_secondary': '#D8DEE9',  # Secondary text
    'accent_red': '#BF616A',      # Red accent
    'accent_green': '#A3BE8C',    # Green for success
    'accent_yellow': '#EBCB8B',   # Yellow for warnings
}

class HardnDashboard:
    def __init__(self):
        self.setup_ui()
        self.running = True
        self.update_interval = 5000  # 5 seconds
        self.start_monitoring()
        
    def setup_ui(self):
        """Set up the main UI"""
        self.window = Gtk.Window()
        self.window.set_title("HARDN-XDR Security Dashboard")
        self.window.set_default_size(1200, 800)
        self.window.set_position(Gtk.WindowPosition.CENTER)
        self.window.connect("delete-event", self.on_delete_event)
        
        # Apply dark theme
        self.apply_theme()
        
        # Create main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        main_box.set_margin_left(10)
        main_box.set_margin_right(10)
        main_box.set_margin_top(10)
        main_box.set_margin_bottom(10)
        
        # Header
        header = self.create_header()
        main_box.pack_start(header, False, False, 0)
        
        # Main content area
        content_paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        
        # Left panel - Status and Controls
        left_panel = self.create_left_panel()
        content_paned.add1(left_panel)
        
        # Right panel - Graphs and Logs
        right_panel = self.create_right_panel()
        content_paned.add2(right_panel)
        
        content_paned.set_position(600)
        main_box.pack_start(content_paned, True, True, 0)
        
        # Status bar
        self.status_bar = Gtk.Statusbar()
        self.status_context = self.status_bar.get_context_id("status")
        self.status_bar.push(self.status_context, "HARDN-XDR Dashboard Ready")
        main_box.pack_start(self.status_bar, False, False, 0)
        
        self.window.add(main_box)
        self.window.show_all()
        
    def apply_theme(self):
        """Apply custom dark theme"""
        css_provider = Gtk.CssProvider()
        css_data = f"""
        window {{
            background-color: {COLORS['bg_primary']};
            color: {COLORS['text_primary']};
        }}
        
        .header {{
            background-color: {COLORS['bg_secondary']};
            color: {COLORS['text_primary']};
            padding: 10px;
            border-radius: 5px;
        }}
        
        .status-box {{
            background-color: {COLORS['bg_secondary']};
            border-radius: 5px;
            padding: 10px;
            margin: 5px;
        }}
        
        .service-running {{
            color: {COLORS['accent_green']};
        }}
        
        .service-stopped {{
            color: {COLORS['accent_red']};
        }}
        
        .service-warning {{
            color: {COLORS['accent_yellow']};
        }}
        
        button {{
            background-color: {COLORS['bg_tertiary']};
            color: {COLORS['text_primary']};
            border: 1px solid {COLORS['accent_red']};
            border-radius: 3px;
            padding: 5px 10px;
        }}
        
        button:hover {{
            background-color: {COLORS['accent_red']};
        }}
        
        treeview {{
            background-color: {COLORS['bg_secondary']};
            color: {COLORS['text_primary']};
        }}
        
        treeview:selected {{
            background-color: {COLORS['accent_red']};
        }}
        """
        
        css_provider.load_from_data(css_data.encode())
        Gtk.StyleContext.add_provider_for_screen(
            self.window.get_screen(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
    def create_header(self):
        """Create the header with title and system info"""
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header_box.get_style_context().add_class("header")
        
        # Title
        title_label = Gtk.Label()
        title_label.set_markup("<b><big>HARDN-XDR Security Dashboard</big></b>")
        header_box.pack_start(title_label, False, False, 0)
        
        # Spacer
        header_box.pack_start(Gtk.Box(), True, True, 0)
        
        # System info
        self.system_info_label = Gtk.Label()
        self.update_system_info()
        header_box.pack_start(self.system_info_label, False, False, 0)
        
        return header_box
        
    def create_left_panel(self):
        """Create the left panel with status and controls"""
        left_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        
        # Services Status
        services_frame = Gtk.Frame(label="Security Services")
        services_frame.get_style_context().add_class("status-box")
        
        self.services_store = Gtk.ListStore(str, str, str)  # Service, Status, Action
        self.services_view = Gtk.TreeView(self.services_store)
        
        # Service column
        service_renderer = Gtk.CellRendererText()
        service_column = Gtk.TreeViewColumn("Service", service_renderer, text=0)
        self.services_view.append_column(service_column)
        
        # Status column
        status_renderer = Gtk.CellRendererText()
        status_column = Gtk.TreeViewColumn("Status", status_renderer, text=1)
        self.services_view.append_column(status_column)
        
        # Action column
        action_renderer = Gtk.CellRendererText()
        action_column = Gtk.TreeViewColumn("Action", action_renderer, text=2)
        self.services_view.append_column(action_column)
        
        services_scrolled = Gtk.ScrolledWindow()
        services_scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        services_scrolled.add(self.services_view)
        services_scrolled.set_size_request(-1, 200)
        
        services_frame.add(services_scrolled)
        left_box.pack_start(services_frame, False, False, 0)
        
        # Control buttons
        control_frame = Gtk.Frame(label="Security Controls")
        control_frame.get_style_context().add_class("status-box")
        
        control_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        
        # Service control buttons
        services_to_control = [
            ("UFW Firewall", "ufw"),
            ("Fail2Ban", "fail2ban"),
            ("AppArmor", "apparmor"),
            ("ClamAV", "clamav-daemon"),
            ("SSH", "ssh"),
        ]
        
        self.control_buttons = {}
        for service_name, service_id in services_to_control:
            button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            
            label = Gtk.Label(service_name)
            label.set_size_request(120, -1)
            button_box.pack_start(label, False, False, 0)
            
            enable_btn = Gtk.Button(label="Enable")
            enable_btn.connect("clicked", self.on_service_enable, service_id)
            button_box.pack_start(enable_btn, False, False, 0)
            
            disable_btn = Gtk.Button(label="Disable")
            disable_btn.connect("clicked", self.on_service_disable, service_id)
            button_box.pack_start(disable_btn, False, False, 0)
            
            self.control_buttons[service_id] = (enable_btn, disable_btn)
            control_box.pack_start(button_box, False, False, 0)
        
        control_frame.add(control_box)
        left_box.pack_start(control_frame, False, False, 0)
        
        # System Parameters
        sysctl_frame = Gtk.Frame(label="Kernel Parameters")
        sysctl_frame.get_style_context().add_class("status-box")
        
        self.sysctl_store = Gtk.ListStore(str, str)  # Parameter, Value
        self.sysctl_view = Gtk.TreeView(self.sysctl_store)
        
        param_renderer = Gtk.CellRendererText()
        param_column = Gtk.TreeViewColumn("Parameter", param_renderer, text=0)
        param_column.set_sizing(Gtk.TreeViewColumnSizing.AUTOSIZE)
        self.sysctl_view.append_column(param_column)
        
        value_renderer = Gtk.CellRendererText()
        value_column = Gtk.TreeViewColumn("Value", value_renderer, text=1)
        value_column.set_sizing(Gtk.TreeViewColumnSizing.AUTOSIZE)
        self.sysctl_view.append_column(value_column)
        
        sysctl_scrolled = Gtk.ScrolledWindow()
        sysctl_scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        sysctl_scrolled.add(self.sysctl_view)
        sysctl_scrolled.set_size_request(-1, 150)
        
        sysctl_frame.add(sysctl_scrolled)
        left_box.pack_start(sysctl_frame, True, True, 0)
        
        return left_box
        
    def create_right_panel(self):
        """Create the right panel with graphs and logs"""
        right_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        
        # Graphs
        graphs_frame = Gtk.Frame(label="System Metrics")
        graphs_frame.get_style_context().add_class("status-box")
        
        # Create matplotlib figure
        self.figure = Figure(figsize=(8, 4), dpi=100)
        self.figure.patch.set_facecolor(COLORS['bg_secondary'])
        
        # CPU and Memory graphs
        self.cpu_ax = self.figure.add_subplot(2, 2, 1)
        self.memory_ax = self.figure.add_subplot(2, 2, 2)
        self.disk_ax = self.figure.add_subplot(2, 2, 3)
        self.network_ax = self.figure.add_subplot(2, 2, 4)
        
        # Initialize data
        self.cpu_data = []
        self.memory_data = []
        self.disk_data = []
        self.network_data = []
        self.time_data = []
        
        # Configure axes
        for ax in [self.cpu_ax, self.memory_ax, self.disk_ax, self.network_ax]:
            ax.set_facecolor(COLORS['bg_primary'])
            ax.tick_params(colors=COLORS['text_primary'])
            ax.spines['bottom'].set_color(COLORS['text_primary'])
            ax.spines['top'].set_color(COLORS['text_primary'])
            ax.spines['right'].set_color(COLORS['text_primary'])
            ax.spines['left'].set_color(COLORS['text_primary'])
            ax.xaxis.label.set_color(COLORS['text_primary'])
            ax.yaxis.label.set_color(COLORS['text_primary'])
        
        self.cpu_ax.set_title('CPU Usage (%)', color=COLORS['text_primary'])
        self.memory_ax.set_title('Memory Usage (%)', color=COLORS['text_primary'])
        self.disk_ax.set_title('Disk Usage (%)', color=COLORS['text_primary'])
        self.network_ax.set_title('Network I/O', color=COLORS['text_primary'])
        
        self.canvas = FigureCanvas(self.figure)
        graphs_frame.add(self.canvas)
        right_box.pack_start(graphs_frame, True, True, 0)
        
        # Logs
        logs_frame = Gtk.Frame(label="Security Logs")
        logs_frame.get_style_context().add_class("status-box")
        
        self.logs_textview = Gtk.TextView()
        self.logs_textview.set_editable(False)
        self.logs_textview.set_cursor_visible(False)
        
        # Configure text buffer
        self.logs_buffer = self.logs_textview.get_buffer()
        
        # Create text tags for different log levels
        self.logs_buffer.create_tag("error", foreground=COLORS['accent_red'])
        self.logs_buffer.create_tag("warning", foreground=COLORS['accent_yellow'])
        self.logs_buffer.create_tag("info", foreground=COLORS['text_primary'])
        self.logs_buffer.create_tag("success", foreground=COLORS['accent_green'])
        
        logs_scrolled = Gtk.ScrolledWindow()
        logs_scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        logs_scrolled.add(self.logs_textview)
        logs_scrolled.set_size_request(-1, 200)
        
        logs_frame.add(logs_scrolled)
        right_box.pack_start(logs_frame, False, False, 0)
        
        return right_box
        
    def start_monitoring(self):
        """Start the monitoring thread"""
        self.monitor_thread = threading.Thread(target=self.monitor_loop, daemon=True)
        self.monitor_thread.start()
        
        # Start periodic UI updates
        GLib.timeout_add(self.update_interval, self.update_ui)
        
    def monitor_loop(self):
        """Background monitoring loop"""
        while self.running:
            try:
                # Update system metrics
                self.update_system_metrics()
                time.sleep(5)
            except Exception as e:
                print(f"Monitor loop error: {e}")
                time.sleep(10)
                
    def update_system_metrics(self):
        """Update system metrics data"""
        current_time = datetime.now()
        
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        
        # Disk usage
        disk = psutil.disk_usage('/')
        disk_percent = disk.percent
        
        # Network I/O
        network = psutil.net_io_counters()
        network_total = network.bytes_sent + network.bytes_recv
        
        # Store data (keep last 50 points)
        max_points = 50
        
        self.cpu_data.append(cpu_percent)
        self.memory_data.append(memory_percent)
        self.disk_data.append(disk_percent)
        self.network_data.append(network_total / 1024 / 1024)  # MB
        self.time_data.append(current_time)
        
        # Trim data if too long
        if len(self.cpu_data) > max_points:
            self.cpu_data = self.cpu_data[-max_points:]
            self.memory_data = self.memory_data[-max_points:]
            self.disk_data = self.disk_data[-max_points:]
            self.network_data = self.network_data[-max_points:]
            self.time_data = self.time_data[-max_points:]
            
    def update_ui(self):
        """Update UI elements"""
        try:
            self.update_services_status()
            self.update_sysctl_parameters()
            self.update_graphs()
            self.update_logs()
            self.update_system_info()
            return True  # Continue periodic updates
        except Exception as e:
            print(f"UI update error: {e}")
            return True
            
    def update_services_status(self):
        """Update services status display"""
        services = [
            ("UFW", "ufw"),
            ("Fail2Ban", "fail2ban"),
            ("AppArmor", "apparmor"),
            ("ClamAV", "clamav-daemon"),
            ("SSH", "ssh"),
            ("Auditd", "auditd"),
            ("Rsyslog", "rsyslog"),
            ("Time Sync", "systemd-timesyncd"),
        ]
        
        self.services_store.clear()
        
        for service_name, service_id in services:
            try:
                # Check service status using systemctl
                result = subprocess.run(
                    ["systemctl", "is-active", service_id],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    status = "Running"
                    action = "Disable"
                else:
                    status = "Stopped"
                    action = "Enable"
                    
            except Exception as e:
                status = "Unknown"
                action = "Check"
                
            self.services_store.append([service_name, status, action])
            
    def update_sysctl_parameters(self):
        """Update kernel parameters display"""
        parameters = [
            "kernel.dmesg_restrict",
            "kernel.kptr_restrict",
            "net.ipv4.ip_forward",
            "net.ipv4.conf.all.accept_redirects",
            "net.ipv4.tcp_syncookies",
            "fs.suid_dumpable",
            "kernel.yama.ptrace_scope",
        ]
        
        self.sysctl_store.clear()
        
        for param in parameters:
            try:
                result = subprocess.run(
                    ["sysctl", "-n", param],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    value = result.stdout.strip()
                else:
                    value = "Not set"
                    
            except Exception as e:
                value = "Error"
                
            self.sysctl_store.append([param, value])
            
    def update_graphs(self):
        """Update the graphs"""
        if not self.cpu_data or not self.time_data:
            return
            
        # Clear axes
        self.cpu_ax.clear()
        self.memory_ax.clear()
        self.disk_ax.clear()
        self.network_ax.clear()
        
        # Plot data
        time_labels = [t.strftime("%H:%M:%S") for t in self.time_data[-10:]]
        
        self.cpu_ax.plot(self.cpu_data[-10:], color=COLORS['accent_red'], linewidth=2)
        self.cpu_ax.set_title('CPU Usage (%)', color=COLORS['text_primary'])
        self.cpu_ax.set_ylim(0, 100)
        
        self.memory_ax.plot(self.memory_data[-10:], color=COLORS['accent_yellow'], linewidth=2)
        self.memory_ax.set_title('Memory Usage (%)', color=COLORS['text_primary'])
        self.memory_ax.set_ylim(0, 100)
        
        self.disk_ax.plot(self.disk_data[-10:], color=COLORS['accent_green'], linewidth=2)
        self.disk_ax.set_title('Disk Usage (%)', color=COLORS['text_primary'])
        self.disk_ax.set_ylim(0, 100)
        
        # Network data (calculate rate)
        if len(self.network_data) > 1:
            network_rate = []
            for i in range(1, len(self.network_data)):
                rate = self.network_data[i] - self.network_data[i-1]
                network_rate.append(max(0, rate))
            
            if network_rate:
                self.network_ax.plot(network_rate[-10:], color=COLORS['text_primary'], linewidth=2)
        
        self.network_ax.set_title('Network I/O (MB/s)', color=COLORS['text_primary'])
        
        # Configure all axes
        for ax in [self.cpu_ax, self.memory_ax, self.disk_ax, self.network_ax]:
            ax.set_facecolor(COLORS['bg_primary'])
            ax.tick_params(colors=COLORS['text_primary'], labelsize=8)
            for spine in ax.spines.values():
                spine.set_color(COLORS['text_primary'])
        
        self.figure.tight_layout()
        self.canvas.draw()
        
    def update_logs(self):
        """Update security logs display"""
        try:
            # Read recent auth log entries
            auth_log = "/var/log/auth.log"
            if os.path.exists(auth_log):
                result = subprocess.run(
                    ["tail", "-n", "10", auth_log],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if result.returncode == 0:
                    # Clear buffer and add new content
                    self.logs_buffer.set_text("")
                    
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            # Determine log level and apply appropriate tag
                            if "FAILED" in line.upper() or "ERROR" in line.upper():
                                tag = "error"
                            elif "WARNING" in line.upper() or "WARN" in line.upper():
                                tag = "warning"
                            elif "SUCCESS" in line.upper() or "ACCEPTED" in line.upper():
                                tag = "success"
                            else:
                                tag = "info"
                            
                            end_iter = self.logs_buffer.get_end_iter()
                            self.logs_buffer.insert_with_tags_by_name(
                                end_iter, line + "\n", tag
                            )
                    
                    # Auto-scroll to bottom
                    mark = self.logs_buffer.get_insert()
                    self.logs_textview.scroll_mark_onscreen(mark)
                    
        except Exception as e:
            print(f"Error updating logs: {e}")
            
    def update_system_info(self):
        """Update system information in header"""
        try:
            hostname = os.uname().nodename
            uptime = subprocess.run(
                ["uptime", "-p"],
                capture_output=True,
                text=True,
                timeout=5
            ).stdout.strip()
            
            load_avg = os.getloadavg()
            
            info_text = f"Host: {hostname} | {uptime} | Load: {load_avg[0]:.2f}"
            self.system_info_label.set_text(info_text)
            
        except Exception as e:
            self.system_info_label.set_text(f"System info error: {e}")
            
    def on_service_enable(self, button, service_id):
        """Handle service enable button click"""
        try:
            result = subprocess.run(
                ["sudo", "systemctl", "enable", "--now", service_id],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                self.status_bar.push(self.status_context, f"Enabled {service_id}")
            else:
                self.status_bar.push(self.status_context, f"Failed to enable {service_id}")
                
        except Exception as e:
            self.status_bar.push(self.status_context, f"Error enabling {service_id}: {e}")
            
    def on_service_disable(self, button, service_id):
        """Handle service disable button click"""
        try:
            result = subprocess.run(
                ["sudo", "systemctl", "disable", "--now", service_id],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                self.status_bar.push(self.status_context, f"Disabled {service_id}")
            else:
                self.status_bar.push(self.status_context, f"Failed to disable {service_id}")
                
        except Exception as e:
            self.status_bar.push(self.status_context, f"Error disabling {service_id}: {e}")
            
    def on_delete_event(self, widget, event):
        """Handle window close event"""
        self.running = False
        Gtk.main_quit()
        return False

def main():
    """Main entry point"""
    # Check if running as root or with sudo
    if os.geteuid() != 0:
        print("Warning: Some features require root privileges")
        print("Consider running with sudo for full functionality")
    
    # Handle SIGINT gracefully
    def signal_handler(sig, frame):
        print("\nShutting down HARDN Dashboard...")
        Gtk.main_quit()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Create and run the dashboard
    dashboard = HardnDashboard()
    
    try:
        Gtk.main()
    except KeyboardInterrupt:
        print("\nShutting down HARDN Dashboard...")
        dashboard.running = False

if __name__ == "__main__":
    main()