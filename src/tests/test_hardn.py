import os
<<<<<<< HEAD
import subprocess
import pytest
from src.gui.main import launch_gui  # from src/gui/main.py

@pytest.fixture
def setup_environment():
    """Fixture to validate the environment before running tests."""
    if os.geteuid() != 0:
        pytest.skip("This test must be run as root. Skipping...")
    print("Environment validated successfully.")

@pytest.fixture
def make_files_executable():
    """Fixture to set executable permissions for required files."""
=======
import sys
import subprocess
from src.gui.main import launch_gui  # Import GUI >>> from src/gui/main.py

import sys
import os

# Add the src directory>>> for wrkflw
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

def validate_environment():
    if os.geteuid() != 0:
        print("This script must be run as root. Please use 'sudo'.")
        sys.exit(1)
    print("Environment validated successfully.")

def set_executable_permissions():
>>>>>>> origin/main
    files_to_chmod = [
        "setup/setup.sh",
        "setup/packages.sh",
        "src/kernel.rs",
    ]

<<<<<<< HEAD
    # Add all files in src/gui to the list
=======
    # Add all files in src/gui to the list[]
>>>>>>> origin/main
    gui_dir = "src/gui"
    for root, _, files in os.walk(gui_dir):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

<<<<<<< HEAD
    for file in files_to_chmod:
        print(f"Setting executable permissions for {file}...")
        subprocess.check_call(["chmod", "+x", file])
    print("All required files are now executable.")

def test_launch_gui(setup_environment):
    """Test to ensure the GUI launches without errors."""
    try:
        launch_gui()
        print("GUI launched successfully.")
    except Exception as e:
        pytest.fail(f"Failed to launch GUI: {e}")

def test_run_setup_scripts(make_files_executable):
    """Test to ensure setup scripts run successfully."""
    scripts = ["setup/setup.sh", "setup/packages.sh"]
    for script in scripts:
        try:
            print(f"Running {script}...")
            subprocess.check_call(["/bin/bash", script])
            print(f"{script} executed successfully.")
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Error running {script}: {e}")

def test_run_kernel():
    """Test to ensure kernel.rs runs successfully."""
=======
    try:
        for file in files_to_chmod:
            print(f"Setting executable permissions for {file}...")
            subprocess.check_call(["chmod", "+x", file])
        print("All required files are now executable.")
    except subprocess.CalledProcessError as e:
        print(f"Error setting executable permissions: {e}")
        sys.exit(1)

def run_script(script_name):
    try:
        print(f"Running {script_name}...")
        subprocess.check_call(["/bin/bash", script_name])
        print(f"{script_name} executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running {script_name}: {e}")
        sys.exit(1)

def run_kernel():
>>>>>>> origin/main
    try:
        print("Running kernel hardening (kernel.rs)...")
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
        print("Kernel hardening completed successfully.")
    except subprocess.CalledProcessError as e:
<<<<<<< HEAD
        pytest.fail(f"Error running kernel.rs: {e}")
=======
        print(f"Error running kernel.rs: {e}")
        sys.exit(1)

def main():
    validate_environment()
    set_executable_permissions()  # Ensure all required files are executable
    launch_gui()  # Launch the GUI
    run_script("setup/setup.sh")  # Run setup.sh
    run_script("setup/packages.sh")  # Run packages.sh
    run_kernel()  # Run kernel.rs

if __name__ == "__main__":
    main()
>>>>>>> origin/main
