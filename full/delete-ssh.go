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

func main() {
    clearScreen()
    cyan := "\033[0;36m"
    reset := "\033[0m"
    fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", cyan, reset)
    fmt.Println("                MEMBER SSH                   ")
    fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", cyan, reset)
    fmt.Println("USERNAME          EXP DATE          STATUS    ")
    fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", cyan, reset)

    file, err := os.Open("/etc/passwd")
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
        line := scanner.Text()
        fields := strings.Split(line, ":")
        username := fields[0]
        uid := fields[2]

        if id, _ := strconv.Atoi(uid); id >= 1000 {
            expDate := getAccountExpireDate(username)
            lockStatus := getAccountLockStatus(username)
            fmt.Printf("%-17s %-17s %-10s\n", username, expDate, lockStatus)
        }
    }

    fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", cyan, reset)
    fmt.Println("                DELETE SSH                   ")
    fmt.Printf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n", cyan, reset)

    fmt.Print("Input Username: ")
    var user string
    fmt.Scanln(&user)

    clearScreen()

    if userExists(user) {
        deleteUser(user)
        clearScreen()
        fmt.Printf("User %s has been successfully deleted.\n", user)
    } else {
        clearScreen()
        fmt.Printf("Failure: User %s not found.\n", user)
    }
}

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

func deleteUser(username string) {
    exec.Command("userdel", username).Run()
    exec.Command("rm", "-fr", fmt.Sprintf("/etc/xray/limit/ip/ssh/%s", username)).Run()
    exec.Command("rm", "-fr", fmt.Sprintf("/var/log/create/ssh/%s.log", username)).Run()
    exec.Command("systemctl", "restart", "dropbear", "ssh", "sshd").Run()
    exec.Command("systemctl", "restart", "ws").Run()
}