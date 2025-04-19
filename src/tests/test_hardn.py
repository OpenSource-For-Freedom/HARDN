# test_gui_setup.py

import os
import sys
import subprocess
import pytest
from unittest import mock

from src.gui.main import launch_gui

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))


@pytest.fixture
def setup_environment():
    if os.geteuid() != 0:
        pytest.skip("This test must be run as root.")


@pytest.fixture
def make_files_executable():
    set_executable_permissions()


def set_executable_permissions():
    files_to_chmod = [
        "src/setup/setup.sh",
        "src/setup/packages.sh",
        "src/kernel.rs",
    ]

    gui_dir = "src/gui"
    for root, _, files in os.walk(gui_dir):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

    for file in files_to_chmod:
        print(f"Setting executable permissions for {file}...")
        try:
            subprocess.check_call(["chmod", "+x", file])
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Failed to set executable permissions for {file}: {e}")

    print("All required files are now executable.")


def test_launch_gui(setup_environment, make_files_executable):
    try:
        launch_gui()
        print("GUI launched successfully.")
    except Exception as e:
        pytest.fail(f"Failed to launch GUI: {e}")


def test_run_setup_scripts(make_files_executable):
    scripts = [
        "src/setup/setup.sh",
        "src/setup/packages.sh",
    ]
    for script in scripts:
        try:
            subprocess.check_call(["/bin/bash", script])
        except subprocess.CalledProcessError as e:
            pytest.fail(f"Error running {script}: {e}")


def test_run_kernel(make_files_executable):
    try:
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
    except subprocess.CalledProcessError as e:
        pytest.fail(f"Error running kernel.rs: {e}")


# ---------- Unit Test for Permission Function ----------
### we are almost to the moon boys....
def test_set_executable_permissions_mocks():
    mock_gui_files = ["gui1.py", "gui2.py"]
    mock_os_walk_result = [("src/gui", [], mock_gui_files)]

    with mock.patch("os.walk", return_value=mock_os_walk_result):
        with mock.patch("subprocess.check_call") as mock_chmod:
            set_executable_permissions()

            expected_calls = [
                mock.call(["chmod", "+x", "src/setup/setup.sh"]),
                mock.call(["chmod", "+x", "src/setup/packages.sh"]),
                mock.call(["chmod", "+x", "src/kernel.rs"]),
                mock.call(["chmod", "+x", "src/gui/gui1.py"]),
                mock.call(["chmod", "+x", "src/gui/gui2.py"]),
            ]
            mock_chmod.assert_has_calls(expected_calls, any_order=False)