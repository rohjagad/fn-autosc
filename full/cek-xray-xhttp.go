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
	output, err := ExecuteCommand("xray", "api", "statsquery", "--server=127.0.0.1:10082")
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
		if strings.Contains(line, "Protokol:") || strings.Contains(line, "Protocol :") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				return strings.ToUpper(fields[len(fields)-1])
			}
		}
	}

	return "Not available"
}


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

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func main() {
	// Clear screen
	clearScreen()
	fmt.Println()
	fmt.Println()
	fmt.Println()
	outerSep := rainbowSepGo("-----------------------------------")

	fmt.Println(outerSep)
	fmt.Println("  Log XRAY XHTTP  ")
	fmt.Println(outerSep)

	// Load user list from config file
	configPath := "/etc/xray/json/xhttp.json"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Println("Config file /etc/xray/json/xhttp.json not found!")
		return
	}

	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading config: %v\n", err)
		return
	}
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
	logPath := "/var/log/xray/xhttp.log"
	if _, err := os.Stat(logPath); os.IsNotExist(err) {
		fmt.Println("Log file /var/log/xray/xhttp.log not found!")
		return
	}

	// Found 494: without the API every per-user read below fails and the loop
	// would silently show nothing. Fail explicitly instead.
	statsUp := false
	if out, err := ExecuteCommand("xray", "api", "statsquery", "--server=127.0.0.1:10082"); err == nil {
		var probe struct {
			Stat []struct {
				Name  string `json:"name"`
				Value int64  `json:"value"`
			} `json:"stat"`
		}
		if json.Unmarshal([]byte(out), &probe) == nil {
			statsUp = true
		}
	}
	if !statsUp {
		fmt.Println("Traffic stats: unavailable (xray API unreachable) — online check skipped.")
		return
	}

	// Process each user
	for _, user := range users {
		ipCountOutput, err := ExecuteCommand("xray", "api", "statsonline", "--server=127.0.0.1:10082", "-email", user)
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
		quotaUsage := ReadFile(filepath.Join("/etc/xray/quota/xhttp", user+"_usage"))
		quotaLimit := ReadFile(filepath.Join("/etc/xray/quota/xhttp", user))
		var quota string
		if quotaUsage == "" || quotaLimit == "" {
			quota = "Not available"
		} else {
			usage, uerr := strconv.ParseInt(quotaUsage, 10, 64)
			limit, lerr := strconv.ParseInt(quotaLimit, 10, 64)
			if uerr != nil || lerr != nil {
				quota = "Not available"
			} else {
				quota = fmt.Sprintf("%s / %s", FormatBytes(usage), FormatBytes(limit))
			}
		}

		// IP limit
		ipLimit := ReadFile(filepath.Join("/etc/xray/limit/ip/xray/xhttp", user))
		if ipLimit == "" {
			ipLimit = "Not available"
		}

		// Protocol
		protocolLogPath := fmt.Sprintf("/var/log/create/xray/xhttp/%s.log", user)
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
		fmt.Println(outerSep)
	}
}
