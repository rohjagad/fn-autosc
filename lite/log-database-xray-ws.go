package main

import (
	"bufio"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const (
	colorReset  = "\033[0m"
	colorGreen  = "\033[0;32m"
	colorBlue   = "\033[1;34m"
	colorPurple = "\033[1;35m"
	colorOrange     = "\033[38;5;208m"
	colorRed        = "\033[0;31m"
	colorDeepPurple = "\033[38;5;141m"
)

func rainbowSep(text string) string {
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

func formatLogForTerminal(raw string) string {
	outerSep := rainbowSep("===================================")
	blueSep := colorBlue + "-----------------------------------" + colorReset

	lines := strings.Split(strings.TrimSpace(raw), "\n")
	var sepIndices []int
	for idx, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "==") || strings.HasPrefix(trimmed, "--") || strings.HasPrefix(trimmed, "━━") {
			sepIndices = append(sepIndices, idx)
		}
	}

	isSep := func(idx int) bool {
		for _, s := range sepIndices {
			if s == idx {
				return true
			}
		}
		return false
	}

	var result []string
	for idx, line := range lines {
		trimmed := strings.TrimSpace(line)
		if isSep(idx) {
			if idx == sepIndices[0] || (len(sepIndices) > 1 && idx == sepIndices[1]) || (len(sepIndices) > 2 && idx == sepIndices[len(sepIndices)-1]) {
				result = append(result, outerSep)
			} else {
				result = append(result, blueSep)
			}
		} else {
			if idx > 0 && isSep(idx-1) && idx < len(lines)-1 && isSep(idx+1) && !strings.HasPrefix(trimmed, "Link ") {
				cleanTitle := strings.TrimSpace(trimmed)
				cleanTitle = strings.TrimPrefix(cleanTitle, "<=")
				cleanTitle = strings.TrimSuffix(cleanTitle, "=>")
				cleanTitle = strings.TrimSpace(cleanTitle)
				result = append(result, colorPurple+cleanTitle+colorReset)
			} else if strings.HasPrefix(trimmed, "Link ") && strings.Contains(line, ":") {
				parts := strings.SplitN(line, ":", 2)
				result = append(result, fmt.Sprintf("%s:%s%s", parts[0], colorDeepPurple, parts[1])+colorReset)
			} else if strings.Contains(line, ":") && !strings.HasPrefix(trimmed, "vmess://") && !strings.HasPrefix(trimmed, "vless://") && !strings.HasPrefix(trimmed, "trojan://") && !strings.HasPrefix(trimmed, "http://") && !strings.HasPrefix(trimmed, "https://") {
				parts := strings.SplitN(line, ":", 2)
				result = append(result, fmt.Sprintf("%s:%s%s", parts[0], colorGreen, parts[1])+colorReset)
			} else {
				result = append(result, line)
			}
		}
	}
	return strings.Join(result, "\n")
}

func main() {
	cmd := exec.Command("bash", "-c", "ls /var/log/create/xray/ws | grep -v '\\.locked$' | sed 's/\\.log$//' | sort | uniq")
	out, err := cmd.Output()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	database := string(out)

	rawLines := strings.Split(strings.TrimSpace(database), "\n")
	var userList []string
	for _, u := range rawLines {
		trimmed := strings.TrimSpace(u)
		if trimmed != "" {
			userList = append(userList, trimmed)
		}
	}

	outerSep := rainbowSep("===================================")
	blueSep := colorBlue + "-----------------------------------" + colorReset

	clearScreen()
	fmt.Printf("%s\n      XTLS WEBSOCKET DATABASE\n%s\n", outerSep, outerSep)
	if len(userList) > 0 {
		for i, u := range userList {
			fmt.Printf("%s%02d%s. %s\n", colorGreen, i+1, colorReset, u)
		}
	} else {
		fmt.Println("No active accounts found.")
	}
	fmt.Println(blueSep)
	fmt.Printf("Total Accounts: %s%d%s\n", colorGreen, len(userList), colorReset)
	fmt.Println(blueSep)
	fmt.Println(colorOrange + "Press [Ctrl + C] to exit" + colorReset)
	fmt.Println(outerSep)

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("\033[96;1mInput Username: \033[0m")
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	username := input
	if num, err := strconv.Atoi(input); err == nil && num >= 1 && num <= len(userList) {
		username = userList[num-1]
	}

	logFile := fmt.Sprintf("/var/log/create/xray/ws/%s.log", username)
	logData, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println("\033[31m404 Log Not Found\033[0m")
		return
	}

	clearScreen()
	fmt.Println(formatLogForTerminal(string(logData)))

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
