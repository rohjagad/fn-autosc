package main

import (
	"encoding/json"
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
	NC    = "\033[0m" // No Color
	BLUE  = "\033[0;34m"
)

// FormatBytes formats bytes into a human-readable string
func FormatBytes(bytes int64) string {
	const (
		KB = 1024
		MB = KB * 1024
		GB = MB * 1024
		TB = GB * 1024
		PB = TB * 1024
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
	case bytes < PB:
		return fmt.Sprintf("%.2f TB", float64(bytes)/TB)
	default:
		return fmt.Sprintf("%.2f PB", float64(bytes)/PB)
	}
}

// ExecuteCommand executes a shell command and returns the output
func ExecuteCommand(command string, args ...string) (string, error) {
	cmd := exec.Command(command, args...)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// ReadFile reads the content of a file as a string
func ReadFile(path string) string {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// ParseStats parses traffic stats for a specific user
func ParseStats(user string, direction string) int64 {
	output, err := ExecuteCommand("xray", "api", "statsquery", "--server=127.0.0.1:10080")
	if err != nil {
		return 0
	}

	var stats struct {
		Stat []struct {
			Name  string `json:"name"`
			Value int64  `json:"value"`
		} `json:"stat"`
	}

	if err := json.Unmarshal([]byte(output), &stats); err != nil {
		return 0
	}

	for _, stat := range stats.Stat {
		if strings.Contains(stat.Name, fmt.Sprintf("user>>>%s>>>traffic>>>%s", user, direction)) {
			return stat.Value
		}
	}

	return 0
}

// ReadProtocolFromLog reads the protocol information from the user's log file
func ReadProtocolFromLog(logFile string) string {
	content, err := ioutil.ReadFile(logFile)
	if err != nil {
		return "Not available"
	}

	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
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
	// Clear screen
	clearScreen()

	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)
	fmt.Println("  Log X-Ray HTTP UPGRADE  ")
	fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)

	// Load user list from config file
	configPath := "/etc/xray/json/split.json"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Println("Config file /etc/xray/json/split.json not found!")
		return
	}

	configData, _ := ioutil.ReadFile(configPath)
	lines := strings.Split(string(configData), "\n")
	userSet := make(map[string]bool) // Avoid duplicate users
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

	// Check if log file exists
	logPath := "/var/log/xray/split.log"
	if _, err := os.Stat(logPath); os.IsNotExist(err) {
		fmt.Println("Log file /var/log/xray/split.log not found!")
		return
	}

	// Process each user
	for _, user := range users {
		ipCountOutput, err := ExecuteCommand("xray", "api", "statsonline", "--server=127.0.0.1:10080", "-email", user)
		if err != nil || ipCountOutput == "" {
			continue
		}

		var stat struct {
			Stat struct {
				Value int `json:"value"`
			} `json:"stat"`
		}

		if err := json.Unmarshal([]byte(ipCountOutput), &stat); err != nil || stat.Stat.Value == 0 {
			continue
		}

		fmt.Printf("\n%sUsername: %s%s%s\n", NC, GREEN, user, NC)

		// Quota usage and limit
		quotaUsage := ReadFile(filepath.Join("/etc/xray/quota/split", user+"_usage"))
		quotaLimit := ReadFile(filepath.Join("/etc/xray/quota/split", user))
		var quota string
		if quotaUsage == "" || quotaLimit == "" {
			quota = "Not available"
		} else {
			usage, _ := strconv.ParseInt(quotaUsage, 10, 64)
			limit, _ := strconv.ParseInt(quotaLimit, 10, 64)
			quota = fmt.Sprintf("%s / %s", FormatBytes(usage), FormatBytes(limit))
		}

		// IP limit
		ipLimit := ReadFile(filepath.Join("/etc/xray/limit/ip/xray/split", user))
		if ipLimit == "" {
			ipLimit = "Not available"
		}

		// Protocol
		protocolLogPath := fmt.Sprintf("/var/log/create/xray/split/%s.log", user)
		protocol := ReadProtocolFromLog(protocolLogPath)

		// Display information
		fmt.Printf("Total IP Login: %d / %s\n", stat.Stat.Value, ipLimit)
		fmt.Printf("Protocol Account: %s\n", protocol)

		// Traffic stats
		uplink := ParseStats(user, "uplink")
		downlink := ParseStats(user, "downlink")

		fmt.Printf("Traffic Uplink: %s\n", FormatBytes(uplink))
		fmt.Printf("Traffic Downlink: %s\n", FormatBytes(downlink))
		fmt.Printf("Quota: %s\n", quota)
		fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━%s\n", BLUE, NC)
	}
}