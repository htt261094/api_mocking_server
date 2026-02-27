import subprocess
import time
import os
import signal
import sys

def run_server():
    print("Starting mock server...")
    return subprocess.Popen([sys.executable, "-m", "mock.server"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def run_tests():
    print("Running Robot tests...")
    result = subprocess.run([sys.executable, "-m", "robot", "tests/"])
    return result.returncode

def main():
    # Ensure dependencies are available
    # In a real scenario, we might want to check for the virtualenv
    
    server_process = run_server()
    time.sleep(2)  # Give the server some time to start

    try:
        exit_code = run_tests()
    except Exception as e:
        print(f"Error running tests: {e}")
        exit_code = 1
    finally:
        print("Stopping mock server...")
        if os.name == 'nt':
            server_process.terminate()
        else:
            os.kill(server_process.pid, signal.SIGTERM)
        
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
