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


func rainbowSepGo(text string) string {
	n := len(text)
	if n == 0 {
		return ""
	}
	red := []int{255, 255, 0, 0, 0, 255, 255}
	green := []int{0, 255, 255, 255, 0, 0, 0}
	blue := []int{0, 0, 0, 255, 255, 255, 0}
	var sb strings.Builder
	for i := 0; i < n; i++ {
		var segment, fraction int
		if i == n-1 {
			segment = 5
			fraction = n - 1
		} else {
			segment = (i * 6) / (n - 1)
			fraction = (i * 6) % (n - 1)
		}
		r := red[segment] + (red[segment+1]-red[segment])*fraction/(n-1)
		g := green[segment] + (green[segment+1]-green[segment])*fraction/(n-1)
		b := blue[segment] + (blue[segment+1]-blue[segment])*fraction/(n-1)
		sb.WriteString(fmt.Sprintf("\033[38;2;%d;%d;%dm%c", r, g, b, text[i]))
	}
	sb.WriteString("\033[0m")
	return sb.String()
}
const (
	colorResetGo = "\033[0m"
	colorBlueGo = "\033[1;34m"
)

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func barisPanjang() {
	fmt.Println(rainbowSepGo("--------------------------------------------------"))
}

func barisBiru() {
	fmt.Println(colorBlueGo + "--------------------------------------------------" + colorResetGo)
}

func rerechanBanner() {
	clearScreen()
	barisPanjang()
	fmt.Println("            Menu Change Limit IP SSH")
	barisPanjang()
}

func Credit() {
	time.Sleep(1 * time.Second)
	barisPanjang()
	fmt.Println(Yellow + "  Terimakasih Telah Menggunakan" + Xark)
	fmt.Println(Yellow + "          Script Credit" + Xark)
	fmt.Println(Yellow + "    FN AutoSC Autoscript AIO" + Xark)
	barisPanjang()
	os.Exit(0)
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
	if CHATID == "" || KEY == "" {
		return
	}
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
		return ""
	}
	return strings.TrimSpace(string(content))
}

// isPositiveInt reports whether s is a base-10 integer >= 1. A value of 0
// is rejected on purpose so it can never silently mean "unlimited" or
// "no limit" - an operator who wants no practical bound enters a
// deliberately large number instead (bug 79).
func isPositiveInt(s string) bool {
	if s == "" {
		return false
	}
	if s[0] == '0' {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

func main() {
	clearScreen()

	fmt.Println("Domain:", getDomain())
	fmt.Println()
    clearScreen()
	rerechanBanner()

	file, err := os.Open("/etc/passwd")
	if err != nil {
		fmt.Println(Red + "Error membuka /etc/passwd" + Xark)
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var usernames []string
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Split(line, ":")
		if len(fields) < 3 {
			continue
		}
		username := fields[0]
		uid := fields[2]

		if id, _ := strconv.Atoi(uid); id >= 1000 && username != "nobody" {
			usernames = append(usernames, username)
		}
	}
	if len(usernames) == 0 {
		fmt.Println("No active accounts found.")
		barisPanjang()
		return
	}
	for i, username := range usernames {
		fmt.Printf("\033[32;1m%02d\033[0m. %-20s %s\n", i+1, username, getIPLimit(username))
	}
	barisBiru()
	fmt.Printf("Total Accounts: %d\n", len(usernames))
	barisBiru()
	fmt.Println("\033[38;5;208mPress [Ctrl + C] to exit\033[0m")
	barisPanjang()

	fmt.Print("Input username: ")
	var input string
	fmt.Scanln(&input)
	fmt.Println()

	// A number picks from the list, a name is used as-is
	user := input
	if n, err := strconv.Atoi(input); err == nil && n >= 1 && n <= len(usernames) {
		user = usernames[n-1]
	}

	limitFile := "/etc/xray/limit/ip/ssh/" + user
	logFile := "/var/log/create/ssh/" + user + ".log"

	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		fmt.Println("Error File " + user + ".log / File Log " + user + " " + Red + "Not Found" + Xark)
		Credit()
		return
	}

	currentIPLimit := getIPLimit(user)
	rerechanBanner()
	fmt.Println(Yellow + " Before " + Xark)
	fmt.Printf(" Username   : %s\n", user)
	fmt.Printf(" Ip Limit   : %s\n", currentIPLimit)
	expiryDate := getAccountExpiry(user)
	fmt.Printf(" Expiry     : %s\n", expiryDate)
	barisPanjang()

	fmt.Println()
	fmt.Println("\033[38;5;208m0 not allowed\033[0m")
	fmt.Print("Input New IP   : ")
	var newIPLimit string
	fmt.Scanln(&newIPLimit)

	loadingAnimasi()

	if !isPositiveInt(newIPLimit) {
		fmt.Println(Red + "Invalid input!" + Xark)
		Credit()
	} else {
		loadingSucces()
		if err := os.WriteFile(limitFile, []byte(newIPLimit), 0644); err != nil {
			fmt.Println("Error memperbarui file limit IP:", err)
		}
		updateLog(logFile, newIPLimit)

		rerechanBanner()
		fmt.Println(Green + " Successfully updated " + Xark)
		fmt.Println()
		fmt.Println(Yellow + " After " + Xark)
		fmt.Printf(" New IP   : %s\n", newIPLimit)
		fmt.Printf(" Username : %s\n", user)
		fmt.Printf(" Expiry   : %s\n", expiryDate)

		sendTelegramNotification(user, currentIPLimit, newIPLimit, expiryDate)
		Credit()
	}
}
