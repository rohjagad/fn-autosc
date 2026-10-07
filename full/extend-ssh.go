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

func main() {
	clearScreen()
	fmt.Println()
	fmt.Println()
	fmt.Println()
	outerSep := rainbowSepGo("-----------------------------------")

	fmt.Println(outerSep)
	fmt.Println("            RENEW  USER")
	fmt.Println(outerSep)

	reader := bufio.NewReader(os.Stdin)

	fmt.Print("Username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	if !userExists(username) {
		clearScreen()
		fmt.Println()
		fmt.Println()
		fmt.Println()
		fmt.Println("\033[31mUsername Doesn't Exist\033[0m")
		return
	}

	fmt.Println()
	fmt.Println("\033[38;5;208m0 not allowed\033[0m")
	fmt.Print("Day Extend (days): ")
	daysInput, _ := reader.ReadString('\n')
	daysInput = strings.TrimSpace(daysInput)
	days, err := strconv.Atoi(daysInput)
	if err != nil || days < 1 {
		clearScreen()
		fmt.Println()
		fmt.Println()
		fmt.Println()
		fmt.Println("\033[31mDays must be a whole number greater than 0\033[0m")
		return
	}

	currentExpiration, err := getUserExpirationDate(username)
	if err != nil {
		clearScreen()
		fmt.Println()
		fmt.Println()
		fmt.Println()
		fmt.Println("\033[31mError retrieving expiration date\033[0m")
		return
	}

	newExpiration := currentExpiration.AddDate(0, 0, days)

	err = updateUserExpiration(username, newExpiration)
	if err != nil {
		clearScreen()
		fmt.Println()
		fmt.Println()
		fmt.Println()
		fmt.Println("\033[31mError updating expiration date\033[0m")
		return
	}

	// Bug 72: expire-ssh locks expired accounts at the next cron tick; a
	// renewal that moves expiry back into the future must restore login.
	if newExpiration.After(time.Now()) {
		if err := exec.Command("passwd", "-u", username).Run(); err != nil {
			clearScreen()
			fmt.Println()
			fmt.Println()
			fmt.Println()
			fmt.Println("\033[31mError unlocking account\033[0m")
			return
		}
	}

	logFilePath := fmt.Sprintf("/var/log/create/ssh/%s.log", username)
	err = updateLogFile(logFilePath, newExpiration)
	if err != nil {
		clearScreen()
		fmt.Println()
		fmt.Println()
		fmt.Println()
		fmt.Println("\033[31mError updating log file\033[0m")
		return
	}

	clearScreen()
	fmt.Println()
	fmt.Println()
	fmt.Println()
	fmt.Println(outerSep)
	fmt.Printf(" Username : %s\n", username)
	fmt.Printf(" Days Added : %d Days\n", days)
	fmt.Printf(" Expires on : %s\n", newExpiration.Format("02-Jan-2006"))
	fmt.Println(outerSep)
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
			dateStr := strings.TrimSpace(strings.SplitN(line, ": ", 2)[1])
			if dateStr == "never" {
				return time.Now(), nil
			}
			parsed, parseErr := time.Parse("Jan 02, 2006", dateStr)
			if parseErr != nil {
				return time.Time{}, parseErr
			}
			return parsed, nil
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
			lines[i] = fmt.Sprintf("Expired    : %s", expiration.Format("02-Jan-2006"))
			break
		}
	}

	newContent := strings.Join(lines, "\n")
	return os.WriteFile(logFilePath, []byte(newContent), 0644)
}
