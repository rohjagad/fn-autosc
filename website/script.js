const form = document.getElementById('uploadForm');
const messageDiv = document.getElementById('message');

form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const fileInput = document.getElementById('file');
    const file = fileInput.files[0];

    if (!file || file.name !== 'backup.zip') {
        showMessage('Error: Please upload a file named "backup.zip".', 'error');
        return;
    }

    const formData = new FormData();
    formData.append('backup', file);

    try {
        showMessage('Uploading and restoring, please wait...', 'info');
        const response = await fetch('upload.php', {
            method: 'POST',
            body: formData
        });

        const result = await response.text();
        showMessage(result, result.includes('SUCCESS') ? 'success' : 'error');
    } catch (error) {
        showMessage(`Error: ${error.message}`, 'error');
    }
});

function showMessage(message, type) {
    messageDiv.textContent = message;
    messageDiv.style.color = type === 'success' ? 'green' : type === 'error' ? 'red' : '#333';
}