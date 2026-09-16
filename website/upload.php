<?php
ob_start();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $target_dir = "/var/www/uploads/";

    if (!is_dir($target_dir)) {
        mkdir($target_dir, 0755, true);
    }

    if (isset($_FILES['backup']) && $_FILES['backup']['error'] === UPLOAD_ERR_OK) {
        $file_name = $_FILES['backup']['name'];
        $file_tmp = $_FILES['backup']['tmp_name'];
        $file_ext = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));

        if ($file_ext === 'zip') {
            $target_file = $target_dir . uniqid('backup_', true) . '.zip';

            if (move_uploaded_file($file_tmp, $target_file)) {
                chmod($target_file, 0644);

                $output = shell_exec("sudo /usr/bin/restore-ftp 2>&1");

                if (strpos("SUCCESSFULL RESTORE YOUR VPS") !== false) {
                    echo "SUCCESSFULLY RESTORED YOUR VPS\n";
                } else {
                    echo "Error: Restore process failed. Output:\n";
                    echo htmlspecialchars($output) . "\n";
                }
            } else {
                echo "Error: Failed to move uploaded file to the target directory.\n";
            }
        } else {
            echo "Error: Invalid file format. Only .zip files are allowed.\n";
        }
    } else {
        echo "Error: No file uploaded or an error occurred during the upload process.\n";
    }
} else {
    echo "Error: Invalid request method.\n";
}

ob_end_flush();
?>