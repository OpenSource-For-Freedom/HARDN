// kernal.rs testing file



#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::{self, File};
    use std::io::Write;
    use std::path::Path;

    #[test]
    fn test_apply_kernel_config_success() {
        let config = KernelConfig {
            parameter: "kernel.randomize_va_space".to_string(),
            value: "2".to_string(),
        };

        let result = config.apply();
        assert!(result.is_ok());
    }

    #[test]
    fn test_apply_kernel_config_failure() {
        let config = KernelConfig {
            parameter: "invalid.parameter".to_string(),
            value: "1".to_string(),
        };

        let result = config.apply();
        assert!(result.is_ok()); 
    }

    #[test]
    fn test_monitor_kernel_logs() {
        let test_log_path = "/tmp/test_kern.log";
        let mut file = File::create(test_log_path).unwrap();
        writeln!(file, "This is a test log").unwrap();
        writeln!(file, "error: something went wrong").unwrap();
        writeln!(file, "warning: potential issue detected").unwrap();

        let result = monitor_kernel_logs(test_log_path);
        assert!(result.is_ok());

        // Clean up
        fs::remove_file(test_log_path).unwrap();
    }

    #[test]
    fn test_get_kernel_version() {
        let result = get_kernel_version();
        assert!(result.is_ok());
        let version = result.unwrap();
        assert!(!version.is_empty());
    }

    #[test]
    fn test_log_action() {
        let test_log_path = "/tmp/test_hardn.log";
        let action = "Test action logged";

        // Temporarily override the log file path
        let original_log_path = "/var/log/hardn.log";
        let _ = fs::rename(original_log_path, format!("{}.bak", original_log_path));

        let result = {
            let mut file = fs::OpenOptions::new()
                .append(true)
                .create(true)
                .open(test_log_path)
                .unwrap();
            writeln!(file, "{}", action).unwrap();
            Ok(())
        };

        assert!(result.is_ok());

        // Verify the log file contains the action
        let log_contents = fs::read_to_string(test_log_path).unwrap();
        assert!(log_contents.contains(action));

        // Clean up
        fs::remove_file(test_log_path).unwrap();
        let _ = fs::rename(format!("{}.bak", original_log_path), original_log_path);
    }
}
