package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"net/http"
	"io/ioutil"
)

func main() {
	// Mendapatkan daftar akun X-Ray http yang aktif
	cmd := exec.Command("bash", "-c", "ls /var/log/create/xray/http | grep -v '\\.locked$' | sed 's/\\.log$//' | sort | uniq")
	out, err := cmd.Output()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	database := string(out)
	total := strings.Count(database, "\n")

	clearScreen()
	fmt.Println("=================================")
	fmt.Println("[ Log Database X-Ray HTTP Account ]")
	fmt.Println("=================================")
	fmt.Println("Username:")
	fmt.Println(database)
	fmt.Println("=================================")
	fmt.Printf("Total Account: %d\n", total)
	fmt.Println("============================")
	fmt.Println("  Press CTRL + C To Exit")

	// Meminta input username
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Input Username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	logFile := fmt.Sprintf("/var/log/create/xray/http/%s.log", username)

	// Mengecek apakah file log ada
	logData, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println("\033[31m404 Log Not Found\033[0m")
		return
	}

	// Mengambil chat ID dan bot token dari file
	chatID, err := ioutil.ReadFile("/etc/funny/.chatid")
	if err != nil {
		fmt.Println("Error reading chat ID:", err)
		return
	}
	key, err := ioutil.ReadFile("/etc/funny/.keybot")
	if err != nil {
		fmt.Println("Error reading bot key:", err)
		return
	}

	// Mengirim log ke Telegram
	sendToTelegram(string(logData), strings.TrimSpace(string(chatID)), strings.TrimSpace(string(key)))

	clearScreen()
	fmt.Println(string(logData))
}

func sendToTelegram(message, chatID, key string) {
	// URL untuk mengirim pesan ke Telegram
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", key)

	// Menyiapkan data yang dikirimkan
	data := "chat_id=" + chatID + "&text=" + message

	// Mengirim request ke Telegram API
	client := &http.Client{}
	req, err := http.NewRequest("POST", url, strings.NewReader(data))
	if err != nil {
		fmt.Println("Error creating request:", err)
		return
	}
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending message to Telegram:", err)
		return
	}
	defer resp.Body.Close()

	// Mengabaikan respons
	_, _ = ioutil.ReadAll(resp.Body)
}

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}