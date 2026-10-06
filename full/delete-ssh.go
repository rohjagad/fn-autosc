package main

import (
    "bufio"
    "fmt"
    "log"
    "os"
    "os/exec"
    "strconv"
    "strings"
)

var sepOuter = rainbowSepGo("------------------------------------------")
var sepBlue = colorBlueGo + "------------------------------------------" + colorResetGo

func main() {
    clearScreen()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    fmt.Println(sepOuter)
    fmt.Println("                MEMBER SSH                   ")
    fmt.Println(sepOuter)
    fmt.Println("USERNAME          EXP DATE          STATUS    ")
    fmt.Println(sepBlue)

    file, err := os.Open("/etc/passwd")
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
        line := scanner.Text()
        fields := strings.Split(line, ":")
        if len(fields) < 3 {
            continue
        }
        username := fields[0]
        uid := fields[2]

        if id, _ := strconv.Atoi(uid); id >= 1000 && id < 65534 {
            expDate := getAccountExpireDate(username)
            lockStatus := getAccountLockStatus(username)
            fmt.Printf("%-17s %-17s %-10s\n", username, expDate, lockStatus)
        }
    }

    fmt.Println(sepOuter)
    fmt.Println("                DELETE SSH                   ")
    fmt.Println(sepOuter)

    fmt.Print("Input Username: ")
    var user string
    fmt.Scanln(&user)

    clearScreen()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    fmt.Println()
    if userExists(user) {
        if err := deleteUser(user); err != nil {
            clearScreen()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Printf("Failure: User %s could not be deleted: %v\n", user, err)
            fmt.Println("The account still exists; remove its running processes and retry.")
        } else {
            clearScreen()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Println()
            fmt.Printf("User %s has been successfully deleted.\n", user)
        }
    } else {
        clearScreen()
        fmt.Println()
        fmt.Println()
        fmt.Println()
        fmt.Println()
        fmt.Println()
        fmt.Printf("Failure: User %s not found.\n", user)
    }
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

func userExists(username string) bool {
    _, err := exec.Command("getent", "passwd", username).Output()
    return err == nil
}

func getAccountExpireDate(username string) string {
    out, _ := exec.Command("chage", "-l", username).Output()
    for _, line := range strings.Split(string(out), "\n") {
        if strings.Contains(line, "Account expires") {
            return strings.TrimSpace(strings.Split(line, ":")[1])
        }
    }
    return "No Expiry"
}

func getAccountLockStatus(username string) string {
    out, _ := exec.Command("passwd", "-S", username).Output()
    if strings.Contains(string(out), " L ") {
        return "LOCKED"
    }
    return "UNLOCKED"
}

func deleteUser(username string) error {
    // -f forces removal even when the account still has a session or a lingering
    // systemd --user; without it userdel exits 8 ("currently used by process"),
    // the account survives, and the menu used to claim success anyway.
    if err := exec.Command("userdel", "-f", username).Run(); err != nil {
        return err
    }
    exec.Command("rm", "-fr", fmt.Sprintf("/etc/xray/limit/ip/ssh/%s", username)).Run()
    exec.Command("rm", "-fr", fmt.Sprintf("/var/log/create/ssh/%s.log", username)).Run()
    exec.Command("systemctl", "restart", "dropbear", "ssh", "sshd").Run()
    exec.Command("systemctl", "restart", "ws").Run()
    return nil
}
