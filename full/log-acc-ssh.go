package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	out, err := exec.Command("bash", "-c", "ls /var/log/create/ssh | sed 's/\\.log$//' | sort | uniq").Output()
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	database := string(out)
	total := strings.Count(database, "\n")

	clearScreen()
	fmt.Println(`
============================
[ Log Database SSH Account ]
============================

Username:
`, database)
	fmt.Printf("============================\nTotal Account: %d\n============================\n", total)
	fmt.Println("  Press CTRL + C To Exit")

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Input Username: ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)

	logFile := fmt.Sprintf("/var/log/create/ssh/%s.log", username)
	logData, err := os.ReadFile(logFile)
	if err != nil {
		fmt.Println("\033[31m404 Log Not Found\033[0m")
	} else {
		// Menampilkan isi log jika file ada
		clearScreen()
		fmt.Println("\n" + string(logData))
	}
}

func clearScreen() {
	cmd := exec.Command("clear")
	cmd.Stdout = os.Stdout
	cmd.Run()
}