package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func main() {
	clearScreen()

	fmt.Println("==========================================")
	fmt.Println("               RENEW  USER                ")
	fmt.Println("==========================================")

	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	if !userExists(username) {
		clearScreen()
		fmt.Println("\033[31mUsername Doesn't Exist\033[0m")
		return
	}

	fmt.Print("Day Extend: ")
	daysInput, _ := reader.ReadString('\n')
	daysInput = strings.TrimSpace(daysInput)
	days, err := strconv.Atoi(daysInput)
	if err != nil {
		clearScreen()
		fmt.Println("\033[31mInvalid input for days\033[0m")
		return
	}

	currentExpiration, err := getUserExpirationDate(username)
	if err != nil {
		clearScreen()
		fmt.Println("\033[31mError retrieving expiration date\033[0m")
		return
	}

	newExpiration := currentExpiration.AddDate(0, 0, days)

	err = updateUserExpiration(username, newExpiration)
	if err != nil {
		clearScreen()
		fmt.Println("\033[31mError updating expiration date\033[0m")
		return
	}

	logFilePath := fmt.Sprintf("/var/log/create/ssh/%s.log", username)
	err = updateLogFile(logFilePath, newExpiration)
	if err != nil {
		clearScreen()
		fmt.Println("\033[31mError updating log file\033[0m")
		return
	}

	clearScreen()
	fmt.Println("==========================================")
	fmt.Printf(" Username : %s\n", username)
	fmt.Printf(" Days Added : %d Days\n", days)
	fmt.Printf(" Expires on : %s\n", newExpiration.Format("Jan 02, 2006"))
	fmt.Println("==========================================")
}

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}

func userExists(username string) bool {
	cmd := exec.Command("id", username)
	if err := cmd.Run(); err != nil {
		return false
	}
	return true
}

func getUserExpirationDate(username string) (time.Time, error) {
	cmd := exec.Command("chage", "-l", username)
	output, err := cmd.Output()
	if err != nil {
		return time.Time{}, err
	}

	for _, line := range strings.Split(string(output), "\n") {
		if strings.Contains(line, "Account expires") {
			dateStr := strings.TrimSpace(strings.Split(line, ": ")[1])
			return time.Parse("Jan 02, 2006", dateStr)
		}
	}
	return time.Time{}, fmt.Errorf("expiration date not found")
}

func updateUserExpiration(username string, expiration time.Time) error {
	expirationStr := expiration.Format("2006-01-02")
	cmd := exec.Command("usermod", "-e", expirationStr, username)
	return cmd.Run()
}

func updateLogFile(logFilePath string, expiration time.Time) error {
	fileContent, err := os.ReadFile(logFilePath)
	if err != nil {
		return err
	}

	lines := strings.Split(string(fileContent), "\n")
	for i, line := range lines {
		if strings.Contains(line, "Expired") {
			lines[i] = fmt.Sprintf("Expired    : %s", expiration.Format("Jan 02, 2006"))
			break
		}
	}

	newContent := strings.Join(lines, "\n")
	return os.WriteFile(logFilePath, []byte(newContent), 0644)
}