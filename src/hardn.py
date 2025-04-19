#!/usr/bin/env python3
import os
import sys
import subprocess
from gui.main import launch_gui  # Import GUI >>> from src/gui/main.py
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def validate_environment():
    if os.geteuid() != 0:
        print("This script must be run as root. Please use 'sudo'.")
        sys.exit(1)
    print("Environment validated successfully.")

def set_executable_permissions():
    files_to_chmod = [
        "src/setup/setup.sh",
        "src/setup/packages.sh",
        "src/kernel.rs",
    ]

    # Add all files in src/gui to the list
    gui_dir = "src/gui"
    for root, _, files in os.walk(gui_dir):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

    for file in files_to_chmod:
        if os.path.exists(file):
            os.chmod(file, 0o755)
            print(f"Set executable permissions for {file}")
        else:
            print(f"Warning: {file} does not exist. Skipping.")

def run_script(script_name):
    try:
        print(f"Running {script_name}...")
        subprocess.check_call(["sudo", "/bin/bash", script_name])
        print(f"{script_name} executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running {script_name}: {e}")
        sys.exit(1)

def run_kernel():
    try:
        print("Running kernel hardening (kernel.rs)...")
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
        print("Kernel hardening completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running kernel.rs: {e}")
        sys.exit(1)

def manage_service(action):
    """
    Manage the hardn.service systemd service.
    :param action: The action to perform (start, stop, restart, status).
    """
    try:
        print(f"{action.capitalize()}ing hardn.service...")
        subprocess.check_call(["systemctl", action, "hardn.service"])
        print(f"hardn.service {action}ed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error {action}ing hardn.service: {e}")
        sys.exit(1)

def main():
    validate_environment()
    set_executable_permissions()  # chmod

    # Stop the service before making changes
    manage_service("stop")

    # Run setup scripts
    run_script("src/setup/setup.sh")
    run_script("src/setup/packages.sh")

    # Run kernel hardening
    run_kernel()

    # Start the service after making changes
    manage_service("start")

    # Launch the GUI
    launch_gui()

if __name__ == "__main__":
    main()