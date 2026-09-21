package main

import (
	"bufio"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	// Mendapatkan daftar akun X-Ray Split yang aktif
	cmd := exec.Command("bash", "-c", "ls /var/log/create/xray/split | grep -v '\\.locked$' | sed 's/\\.log$//' | sort | uniq")
	out, err := cmd.Output()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	database := string(out)
	total := strings.Count(database, "\n")

	clearScreen()
	fmt.Println("====================================")
	fmt.Println("[ Log Database X-Ray Split Account ]")
	fmt.Println("====================================")
	fmt.Println("Username:")
	fmt.Println(database)
	fmt.Println("====================================")
	fmt.Printf("Total Accounts: %d\n", total)
	fmt.Println("====================================")
	fmt.Println("    Press [Ctrl + C] to exit")

	// Meminta input username
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Input Username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	logFile := fmt.Sprintf("/var/log/create/xray/split/%s.log", username)

	// Mengecek apakah file log ada
	logData, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println("\033[31m404 Log Not Found\033[0m")
		return
	}

	clearScreen()
	fmt.Println(string(logData))

	// Mengambil chat ID dan bot token jika bot sudah di-setup
	chatIDBytes, errChat := os.ReadFile("/etc/funny/.chatid")
	keyBytes, errKey := os.ReadFile("/etc/funny/.keybot")
	if errChat == nil && errKey == nil {
		chatID := strings.TrimSpace(string(chatIDBytes))
		key := strings.TrimSpace(string(keyBytes))
		if chatID != "" && key != "" {
			sendToTelegram(string(logData), chatID, key)
		}
	}
}

func sendToTelegram(message, chatID, key string) {
	if chatID == "" || key == "" {
		return
	}
	urlStr := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", key)
	formData := url.Values{
		"chat_id": {chatID},
		"text":    {message},
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.PostForm(urlStr, formData)
	if err != nil {
		return
	}
	defer resp.Body.Close()
}

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}
