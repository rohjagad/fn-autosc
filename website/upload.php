<?php
ob_start();

// Restoring a backup runs `sudo /usr/bin/restore-ftp` as root, which overwrites
// /etc/passwd, /etc/shadow, /etc/group, /etc/crontab, /etc/xray and more with
// the contents of the uploaded archive. The endpoint must therefore
// authenticate BEFORE it accepts the file, or anyone who can reach this port
// can take over the VPS.
//
// The shared secret is a dedicated restore key, /etc/funny/.restore.key,
// generated at install time and readable only by root and the web server user
// (mode 0640 root:www-data). It is deliberately not the API token: that file is
// 0600 root and must stay that way. The request may carry the key as the
// `token` form field or as an Authorization header. If the key file is missing
// or unreadable the endpoint refuses to run - fail closed.
function restore_provided_token(): string {
    if (isset($_POST['token'])) {
        return trim((string) $_POST['token']);
    }
    // Apache does not expose the Authorization header to PHP as
    // $_SERVER['HTTP_AUTHORIZATION'] unless it is passed through explicitly, so
    // also look where mod_php / the rewrite module may have put it.
    foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $var) {
        if (!empty($_SERVER[$var])) {
            return trim((string) $_SERVER[$var]);
        }
    }
    if (function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                return trim((string) $value);
            }
        }
    }
    return '';
}

function restore_token_ok(): bool {
    $keyFile = '/etc/funny/.restore.key';
    if (!is_readable($keyFile)) {
        return false;
    }
    $tokens = array_filter(array_map('trim', file($keyFile, FILE_IGNORE_NEW_LINES)));
    if (!$tokens) {
        return false;
    }
    $provided = restore_provided_token();
    if ($provided === '') {
        return false;
    }
    foreach ($tokens as $token) {
        if (hash_equals($token, $provided)) {
            return true;
        }
    }
    return false;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!restore_token_ok()) {
        http_response_code(401);
        echo "Error: Unauthorized. A valid restore key is required to restore a backup.\n";
        ob_end_flush();
        exit;
    }

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

                if (strpos($output, "SUCCESSFULL RESTORE YOUR VPS") !== false) {
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
