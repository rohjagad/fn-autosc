package main

import (
	"fmt"
	"path/filepath"
	"os"
	"strings"
	"time"
)

const (
	Green  = "\033[32m"
	Yellow = "\033[33m"
	Red    = "\033[31m"
	Xark   = "\033[0m"
)

func barisPanjang() {
	fmt.Println("──────────────────────────────────────────────────")
}

func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func rerechanBanner() {
	barisPanjang()
	fmt.Println("                      FN AutoSC")
	fmt.Println("──────────────────────────────────────────────────")
	fmt.Println("          Menu Change Limit IP X-Ray Split HTTP")
	fmt.Println("──────────────────────────────────────────────────")
}

func Credit() {
	fmt.Println("   Powered by FN AutoSC")
}

func loadingAnimasi() {
	for i := 0; i < 3; i++ {
		fmt.Print(".")
		time.Sleep(500 * time.Millisecond)
	}
	fmt.Println()
}

func loadingSucces() {
	fmt.Println(Green + "Successfully updated!" + Xark)
}

func getAccountExpiry(logFile string) string {
	content, err := os.ReadFile(logFile)
	if err != nil {
		return "N/A"
	}

	for _, line := range strings.Split(string(content), "\n") {
		if strings.HasPrefix(line, "Expired :") {
			return strings.TrimSpace(strings.Split(line, ":")[1])
		}
	}
	return "N/A"
}

func getIPLimit(logFile string) string {
	content, err := os.ReadFile(logFile)
	if err != nil {
		return "No Limit Set"
	}

	for _, line := range strings.Split(string(content), "\n") {
		if strings.HasPrefix(line, "Limit IP:") {
			return strings.TrimSpace(strings.Split(line, ":")[1])
		}
	}
	return "No Limit Set"
}

func getUsernames() []string {
	var usernames []string
	dir := "/var/log/create/xray/split"

	files, err := os.ReadDir(dir)
	if err != nil {
		fmt.Println(Red + "Error membaca direktori log: " + err.Error() + Xark)
		return usernames
	}

	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".log") && !strings.HasSuffix(file.Name(), ".locked") {
			username := strings.TrimSuffix(file.Name(), ".log")
			usernames = append(usernames, username)
		}
	}
	return usernames
}

func updateLog(logFile string, newIPLimit string) {
	content, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println(Red + "Error membaca file log: " + err.Error() + Xark)
		return
	}

	lines := strings.Split(string(content), "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "Limit IP:") {
			lines[i] = "Limit IP: " + newIPLimit
		}
	}

	err = os.WriteFile(logFile, []byte(strings.Join(lines, "\n")), 0644)
	if err != nil {
		fmt.Println(Red + "Error memperbarui file log: " + err.Error() + Xark)
	}
}


// Bug 62: also update the enforced/displayed limit file that cek-xray reads,
// so the change is reflected everywhere instead of only in the account log.
func updateLimitFile(user, newIPLimit string) {
	limitDir := "/etc/xray/limit/ip/xray/split"
	if err := os.MkdirAll(limitDir, 0755); err != nil {
		fmt.Println(Red + "Error creating IP limit directory: " + err.Error() + Xark)
		return
	}
	if err := os.WriteFile(filepath.Join(limitDir, user), []byte(newIPLimit+"\n"), 0644); err != nil {
		fmt.Println(Red + "Error updating IP limit file: " + err.Error() + Xark)
	}
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
	rerechanBanner()

	barisPanjang()
	fmt.Println("   USERNAME       EXP DATE         LIMIT IP")
	barisPanjang()

	usernames := getUsernames()
	var count int

	for _, username := range usernames {
		logFile := fmt.Sprintf("/var/log/create/xray/split/%s.log", username)
		expiry := getAccountExpiry(logFile)
		ipLimit := getIPLimit(logFile)
		fmt.Printf(" %-17s %-15s %-20s\n", username, expiry, ipLimit)
		count++
	}

	barisPanjang()
	fmt.Printf("   Account number: %d users\n", count)
	barisPanjang()

	fmt.Print("Input username: ")
	var user string
	fmt.Scanln(&user)

	logFile := "/var/log/create/xray/split/" + user + ".log"
	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		rerechanBanner()
		fmt.Println("Error: File log " + user + ".log tidak ditemukan.")
		Credit()
		return
	}

	currentIPLimit := getIPLimit(logFile)
	rerechanBanner()
	barisPanjang()
	fmt.Println(Yellow + " Before " + Xark)
	fmt.Printf(" Username   : %s\n", user)
	fmt.Printf(" Exp Date   : %s\n", getAccountExpiry(logFile))
	fmt.Printf(" Ip Limit   : %s\n", currentIPLimit)
	barisPanjang()

	fmt.Println()
	fmt.Println("\033[38;5;208m0 not allowed\033[0m")
	fmt.Print("Input New IP Limit: ")
	var newIPLimit string
	fmt.Scanln(&newIPLimit)

	loadingAnimasi()

	if !isPositiveInt(newIPLimit) {
		fmt.Println(Red + "Invalid input!" + Xark)
	} else {
		// keep the limit file cek-xray reads in sync (Bug 62)
		updateLog(logFile, newIPLimit)
		updateLimitFile(user, newIPLimit)
	    clearScreen()
		rerechanBanner()
		barisPanjang()
		fmt.Println(Green + " Successfully updated " + Xark)
		fmt.Println()
		fmt.Println(Yellow + " After " + Xark)
		fmt.Printf(" Username : %s\n", user)
		fmt.Printf(" Exp Date : %s\n", getAccountExpiry(logFile))
		fmt.Printf(" New IP   : %s\n", newIPLimit)
		barisPanjang()
		Credit()
	}
}