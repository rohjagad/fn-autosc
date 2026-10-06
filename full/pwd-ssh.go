package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var sepOuter = rainbowSepGo("-----------------------------------------------")
var sepBlue = colorBlueGo + "-----------------------------------------------" + colorResetGo

func main() {
	clearScreen()
	fmt.Println()
	fmt.Println("\n\n\n")
	clearScreen()
	fmt.Println()
	fmt.Println(sepOuter)
	fmt.Println("          CHANGE PASSWORD SSH Account          ")
	fmt.Println(sepOuter)
	fmt.Println("Username           |  Password   |  Expired")
	fmt.Println(sepBlue)

	displayAllAccountInfo("/var/log/create/ssh")

	fmt.Println(sepOuter)
	var username string
	fmt.Print("Input username to change password: ")
	fmt.Scanln(&username)
	if !checkUserExists(username) {
		fmt.Println(sepOuter)
		fmt.Printf("Username %s not found on your VPS\n", username)
		fmt.Println(sepOuter)
		return
	}

	logFilePath := fmt.Sprintf("/var/log/create/ssh/%s.log", username)

	fmt.Printf("Input new password for user %s: ", username)
	var newPassword string
	fmt.Scanln(&newPassword)

	clearScreen()
	fmt.Println()
	fmt.Println("Connecting to Server...")
	sleep(500)
	fmt.Println("Generating New Password...")
	sleep(500)

	err := changePassword(username, newPassword)
	if err != nil {
		fmt.Printf("Error changing password: %v\n", err)
		return
	}

	err = updateLogPassword(logFilePath, newPassword)
	if err != nil {
		fmt.Printf("Error updating log file: %v\n", err)
		return
	}

	clearScreen()
	fmt.Println()
	fmt.Println("\n\n\n")
	clearScreen()
	fmt.Println()
	fmt.Println(sepOuter)
	fmt.Printf("Password for user %s successfully changed.\n", username)
	fmt.Printf("The new Password for user %s is %s\n", username, newPassword)
	fmt.Println(sepOuter)
	fmt.Println("\n\n")
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
const (
	colorResetGo = "\033[0m"
	colorBlueGo = "\033[1;34m"
)

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func checkUserExists(username string) bool {
	cmd := exec.Command("grep", fmt.Sprintf("^%s:", username), "/etc/passwd")
	err := cmd.Run()
	return err == nil
}

func displayAllAccountInfo(logDir string) {
	files, err := filepath.Glob(filepath.Join(logDir, "*.log"))
	if err != nil {
		fmt.Printf("Error accessing log directory: %v\n", err)
		return
	}

	for _, file := range files {
		displayAccountInfo(file)
	}
}

func displayAccountInfo(logFilePath string) {
	file, err := os.Open(logFilePath)
	if err != nil {
		fmt.Printf("Error reading log file: %v\n", err)
		return
	}
	defer file.Close()

	var username, password, expired string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "Username") {
			username = extractField(line)
		} else if strings.HasPrefix(line, "Password") {
			password = extractField(line)
		} else if strings.HasPrefix(line, "Expired") {
			expired = extractField(line)
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("Error scanning log file: %v\n", err)
	}

	fmt.Printf("%-18s | %-10s | %-12s\n", username, password, expired)
}

func extractField(line string) string {
	parts := strings.SplitN(line, ":", 2)
	if len(parts) == 2 {
		return strings.TrimSpace(parts[1])
	}
	return ""
}

func changePassword(username, newPassword string) error {
	cmd := exec.Command("passwd", username)
	cmd.Stdin = strings.NewReader(fmt.Sprintf("%s\n%s\n", newPassword, newPassword))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func updateLogPassword(logFilePath, newPassword string) error {
	file, err := os.Open(logFilePath)
	if err != nil {
		return fmt.Errorf("could not open log file: %v", err)
	}

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "Password   :") {
			line = fmt.Sprintf("Password   : %s", newPassword)
		}
		lines = append(lines, line)
	}
	if err := scanner.Err(); err != nil {
		file.Close()
		return fmt.Errorf("error reading log file: %v", err)
	}
	file.Close()

	file, err = os.Create(logFilePath)
	if err != nil {
		return fmt.Errorf("could not open log file for writing: %v", err)
	}
	defer file.Close()

	for _, line := range lines {
		_, err := file.WriteString(line + "\n")
		if err != nil {
			return fmt.Errorf("error writing to log file: %v", err)
		}
	}

	return nil
}

func sleep(ms int) {
	time.Sleep(time.Duration(ms) * time.Millisecond)
}
