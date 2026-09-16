package main

import (
	"bufio"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
	"net/url"
)

var (
	Red      = "\033[91;1m"
	Yellow   = "\033[93;1m"
	BlueCyan = "\033[5;36m"
	Green    = "\033[92;1m"
	Xark     = "\033[0m"
)

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func barisPanjang() {
	fmt.Println(BlueCyan + "──────────────────────────────────────────────────" + Xark)
}

func rerechanBanner() {
	clearScreen()
	barisPanjang()
	fmt.Println(Yellow + "             FN PROJECT" + Xark)
	barisPanjang()
}

func Credit() {
	time.Sleep(1)
	barisPanjang()
	fmt.Println(Yellow + "  Terimakasih Telah Menggunakan" + Xark)
	fmt.Println(Yellow + "          Script Credit" + Xark)
	fmt.Println(Yellow + "    FN PROJECT Autoscript AIO" + Xark)
	barisPanjang()
	os.Exit(1)
}

func loadingAnimasi() {
	frames := []string{"██10%", "█████35%", "█████████65%", "█████████████80%", "█████████████████████90%", "█████████████████████████100%"}
	for i := 0; i < len(frames); i++ {
		clearScreen()
		fmt.Println(frames[i])
		time.Sleep(500 * time.Millisecond)
	}
}

func loadingSucces() {
	clearScreen()
	fmt.Println(Green + "Success" + Xark)
	time.Sleep(1 * time.Second)
	clearScreen()
}

func getDomain() string {
	content, err := os.ReadFile("/etc/xray/domain")
	if err != nil {
		fmt.Println(Red + "Error membaca domain" + Xark)
		return ""
	}
	return strings.TrimSpace(string(content))
}

func getAccountExpiry(username string) string {
	cmd := exec.Command("chage", "-l", username)
	output, err := cmd.Output()
	if err != nil {
		return "never"
	}
	for _, line := range strings.Split(string(output), "\n") {
		if strings.HasPrefix(line, "Account expires") {
			return strings.TrimSpace(strings.Split(line, ":")[1])
		}
	}
	return "never"
}

func getIPLimit(username string) string {
	limitFile := "/etc/xray/limit/ip/ssh/" + username
	content, err := os.ReadFile(limitFile)
	if err != nil {
		return "No Limit Set"
	}
	return strings.TrimSpace(string(content))
}

func updateLog(logFile, newIPLimit string) {
	fileContent, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println("Error membaca file log:", err)
		return
	}

	newContent := strings.ReplaceAll(string(fileContent), "Limit IP   : "+getCurrentIPLimit(string(fileContent)), "Limit IP   : "+newIPLimit)

	if err := os.WriteFile(logFile, []byte(newContent), 0644); err != nil {
		fmt.Println("Error memperbarui file log:", err)
	}
}

func getCurrentIPLimit(content string) string {
	for _, line := range strings.Split(content, "\n") {
		if strings.HasPrefix(line, "Limit IP   : ") {
			return strings.TrimSpace(strings.Split(line, ":")[1])
		}
	}
	return ""
}

func sendTelegramNotification(username, oldLimit, newLimit, expiry string) {
	CHATID := string(readFile("/etc/funny/.chatid"))
	KEY := string(readFile("/etc/funny/.keybot"))
	URL := "https://api.telegram.org/bot" + KEY + "/sendMessage"

	date := time.Now().Format("2006-01-02")
	message := fmt.Sprintf(`
		<b>🔒 Change Limit IP SSH</b>
		<b>──────────────────────────────────</b>
		<b>👤 Username:</b> %s
		<b>🌐 Old Limit IP:</b> %s
		<b>🔄 New Limit IP:</b> %s
		<b>⏳ Expiry:</b> %s
		<b>📅 Change Date:</b> %s
		<b>──────────────────────────────────</b>
		<b>✅ Update Successful!</b>
	`, username, oldLimit, newLimit, expiry, date)

	data := url.Values{}
	data.Set("chat_id", CHATID)
	data.Set("text", message)
	data.Set("parse_mode", "html")
	data.Set("disable_web_page_preview", "true")

	resp, err := http.PostForm(URL, data)
	if err != nil {
		fmt.Println(Red + "Error sending message to Telegram:" + err.Error() + Xark)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf(Red + "Failed to send message: %s" + Xark, resp.Status)
	} else {
		fmt.Println(Green + "Telegram notification sent successfully!" + Xark)
	}
}

func readFile(filePath string) string {
	content, err := os.ReadFile(filePath)
	if err != nil {
		fmt.Println(Red + "Error reading file: " + filePath + Xark)
		return ""
	}
	return strings.TrimSpace(string(content))
}

func main() {
	clearScreen()

	fmt.Println("Domain:", getDomain())
	fmt.Println()
    clearScreen()
	barisPanjang()
	fmt.Println("   USERNAME       EXP DATE         LIMIT IP")
	barisPanjang()

	file, err := os.Open("/etc/passwd")
	if err != nil {
		fmt.Println(Red + "Error membuka /etc/passwd" + Xark)
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var count int
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Split(line, ":")
		if len(fields) < 3 {
			continue
		}
		username := fields[0]
		uid := fields[2]

		if id, _ := strconv.Atoi(uid); id >= 1000 && username != "nobody" {
			expiry := getAccountExpiry(username)
			ipLimit := getIPLimit(username)
			fmt.Printf(" %-17s %-15s %-20s\n", username, expiry, ipLimit)
			count++
		}
	}

	barisPanjang()
	fmt.Printf("   Account number: %d users\n", count)
	barisPanjang()

	fmt.Print("Input username: ")
	var user string
	fmt.Scanln(&user)

	limitFile := "/etc/xray/limit/ip/ssh/" + user
	logFile := "/var/log/create/ssh/" + user + ".log"

	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		rerechanBanner()
		fmt.Println("Error File " + user + ".log / File Log " + user + " " + Red + "Not Found" + Xark)
		Credit()
		return
	}

	if _, err := os.Stat(limitFile); err == nil {
		currentIPLimit := getIPLimit(user)
		rerechanBanner()
		barisPanjang()
		fmt.Println(Yellow + " Before " + Xark)
		fmt.Printf(" Username   : %s\n", user)
		fmt.Printf(" Ip Limit   : %s\n", currentIPLimit)
		expiryDate := getAccountExpiry(user)
		fmt.Printf(" Expiry     : %s\n", expiryDate)
		barisPanjang()

		fmt.Print("Input New IP   : ")
		var newIPLimit string
		fmt.Scanln(&newIPLimit)

		loadingAnimasi()
		loadingSucces()

		if newIPLimit == "" {
			fmt.Println(Red + "Invalid input!" + Xark)
		} else {
			if err := os.WriteFile(limitFile, []byte(newIPLimit), 0644); err != nil {
				fmt.Println("Error memperbarui file limit IP:", err)
			}
			updateLog(logFile, newIPLimit)

			rerechanBanner()
			barisPanjang()
			fmt.Println(Green + " Successfully updated " + Xark)
			fmt.Println()
			fmt.Println(Yellow + " After " + Xark)
			fmt.Printf(" New IP   : %s\n", newIPLimit)
			fmt.Printf(" Username : %s\n", user)
			fmt.Printf(" Expiry   : %s\n", expiryDate)

			sendTelegramNotification(user, currentIPLimit, newIPLimit, expiryDate)
			Credit()
		}
	} else
    {
		rerechanBanner()
		fmt.Println(Red + "Error: Limit IP untuk username " + user + " tidak ditemukan!" + Xark)
		Credit()
	}
}