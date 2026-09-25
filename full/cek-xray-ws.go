package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	GREEN = "\033[32;1m"
	NC    = "\033[0m"
	BLUE  = "\033[0;34m"
)

func FormatBytes(bytes int64) string {
	const (
		KB = 1024
		MB = KB * 1024
		GB = MB * 1024
		TB = GB * 1024
	)
	switch {
	case bytes < KB:
		return fmt.Sprintf("%d B", bytes)
	case bytes < MB:
		return fmt.Sprintf("%.2f KB", float64(bytes)/KB)
	case bytes < GB:
		return fmt.Sprintf("%.2f MB", float64(bytes)/MB)
	case bytes < TB:
		return fmt.Sprintf("%.2f GB", float64(bytes)/GB)
	default:
		return fmt.Sprintf("%.2f TB", float64(bytes)/TB)
	}
}

func ReadFile(path string) string {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func ReadProtocolFromLog(logFile string) string {
	content, err := ioutil.ReadFile(logFile)
	if err != nil {
		return "Not available"
	}
	for _, line := range strings.Split(string(content), "\n") {
		if strings.Contains(line, "Protokol:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				return fields[1]
			}
		}
	}
	return "Not available"
}

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func main() {
	clearScreen()

	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)
	fmt.Println("    Log X-Ray WebSocket   ")
	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)

	configPath := "/etc/xray/json/ws.json"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Println("Config file /etc/xray/json/ws.json not found!")
		return
	}

	configData, _ := ioutil.ReadFile(configPath)
	lines := strings.Split(string(configData), "\n")
	userSet := make(map[string]bool)
	users := []string{}

	for _, line := range lines {
		if strings.HasPrefix(line, "###") {
			fields := strings.Fields(line)
			if len(fields) >= 2 && !userSet[fields[1]] {
				userSet[fields[1]] = true
				users = append(users, fields[1])
			}
		}
	}

	if len(users) == 0 {
		fmt.Println("No users found in config!")
		return
	}

	for _, user := range users {
		fmt.Printf("\n%sUsername: %s%s%s\n", NC, GREEN, user, NC)

		quotaUsage := ReadFile(filepath.Join("/etc/xray/quota/ws", user+"_usage"))
		quotaLimit := ReadFile(filepath.Join("/etc/xray/quota/ws", user))
		var quota string
		if quotaUsage == "" || quotaLimit == "" {
			quota = "Not available"
		} else {
			usage, _ := strconv.ParseInt(quotaUsage, 10, 64)
			limit, _ := strconv.ParseInt(quotaLimit, 10, 64)
			quota = fmt.Sprintf("%s / %s", FormatBytes(usage), FormatBytes(limit))
		}

		ipLimit := ReadFile(filepath.Join("/etc/xray/limit/ip/xray/ws", user))
		if ipLimit == "" {
			ipLimit = "Not available"
		}

		protocolLogPath := fmt.Sprintf("/var/log/create/xray/ws/%s.log", user)
		protocol := ReadProtocolFromLog(protocolLogPath)

		fmt.Printf("IP Limit: %s\n", ipLimit)
		fmt.Printf("Protocol: %s\n", protocol)
		fmt.Printf("Quota: %s\n", quota)
		fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)
	}
}
