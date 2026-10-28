// FourColour installer for reMarkable (XOVI + AppLoad).
// Installs, updates or removes the FourColour comic reader (AppLoad id "rm-comics").
package main

import (
	"bufio"
	"bytes"
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"net"
	"os"
	"path"
	"strings"
	"sync"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"golang.org/x/term"
)

const (
	version    = "1.5.1"
	appName    = "FourColour"
	appID      = "rm-comics"
	defaultIP  = "10.11.99.1"
	defaultUsr = "root"
	apploadDir = "/home/root/xovi/exthome/appload"
	appDir     = apploadDir + "/" + appID
	comicsDir  = "/home/root/comics"
	stateDir   = "/home/root/.local/share/rm-comics"
	cacheDir   = "/home/root/.cache/rm-comics"
	tmpDir     = "/home/root/.fourcolour-installer-tmp"
)

//go:embed payload
var payload embed.FS

// Files to install: embedded path -> path relative to appDir, mode.
type payloadFile struct {
	src  string
	dest string
	mode os.FileMode
}

var files = []payloadFile{
	{"payload/manifest.json", "manifest.json", 0644},
	{"payload/resources.rcc", "resources.rcc", 0644},
	{"payload/icon.png", "icon.png", 0644},
	{"payload/backend/entry", "backend/entry", 0755},
}

var in = bufio.NewReader(os.Stdin)

func main() {
	code := run()
	fmt.Println()
	prompt("Press Enter to exit.")
	os.Exit(code)
}

func run() int {
	fmt.Printf("%s installer, version %s\n", appName, version)
	fmt.Println(strings.Repeat("-", 40))
	fmt.Println("This installs, updates or removes the FourColour comic reader on a")
	fmt.Println("reMarkable tablet that already has XOVI and AppLoad installed.")
	fmt.Println()
	fmt.Println("Before you start:")
	fmt.Println("  - Connect the tablet to this computer with its USB cable, switch it on and unlock it.")
	fmt.Println("  - Close FourColour on the tablet if it is open.")
	fmt.Println("  - You need the tablet's SSH password. On the tablet go to")
	fmt.Println("    Settings > General > Help > About > Copyrights and licenses and scroll down;")
	fmt.Println("    the password is shown there (developer mode is needed for SSH).")
	fmt.Println()

	host := ask("Tablet IP address", defaultIP)
	user := ask("Username", defaultUsr)
	pass := askPassword("Password (it won't show as you type): ")
	fmt.Println()

	fmt.Printf("Connecting to %s@%s ...\n", user, host)
	client, err := connect(host, user, pass)
	if err != nil {
		fmt.Println()
		fmt.Println(friendlyConnError(err, host))
		return 1
	}
	defer client.Close()
	fmt.Println("Connected.")

	if err := checkAppLoad(client); err != nil {
		fmt.Println()
		fmt.Println(err)
		return 1
	}

	for {
		fmt.Println()
		fmt.Println("What would you like to do?")
		fmt.Println("  1  Install or update FourColour")
		fmt.Println("  2  Uninstall FourColour")
		fmt.Println("  3  Quit")
		switch strings.TrimSpace(prompt("Choose 1, 2 or 3: ")) {
		case "1":
			if err := install(client); err != nil {
				fmt.Println()
				fmt.Println("Installation failed:", err)
				fmt.Println("Your comics and saved pages have not been touched.")
				return 1
			}
			return 0
		case "2":
			if err := uninstall(client); err != nil {
				fmt.Println()
				fmt.Println("Uninstall failed:", err)
				return 1
			}
			return 0
		case "3", "q", "Q":
			fmt.Println("Nothing was changed.")
			return 0
		default:
			fmt.Println("Please type 1, 2 or 3.")
		}
	}
}

// ---------- prompts ----------

func prompt(msg string) string {
	fmt.Print(msg)
	line, err := in.ReadString('\n')
	if err != nil && line == "" {
		return ""
	}
	return strings.TrimRight(line, "\r\n")
}

func ask(label, def string) string {
	v := strings.TrimSpace(prompt(fmt.Sprintf("%s [%s]: ", label, def)))
	if v == "" {
		return def
	}
	return v
}

func askPassword(label string) string {
	fmt.Print(label)
	fd := int(os.Stdin.Fd())
	if term.IsTerminal(fd) {
		b, err := term.ReadPassword(fd)
		fmt.Println()
		if err == nil {
			return string(b)
		}
	}
	// Not an interactive console (e.g. piped input): read a plain line.
	return prompt("")
}

func yesNo(q string, def bool) bool {
	d := "y/N"
	if def {
		d = "Y/n"
	}
	for {
		a := strings.ToLower(strings.TrimSpace(prompt(fmt.Sprintf("%s [%s]: ", q, d))))
		switch a {
		case "":
			return def
		case "y", "yes":
			return true
		case "n", "no":
			return false
		}
		fmt.Println("Please type y or n.")
	}
}

// ---------- SSH ----------

func sshConfig(user, pass string) *ssh.ClientConfig {
	cfg := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.Password(pass),
			ssh.KeyboardInteractive(func(_, _ string, qs []string, _ []bool) ([]string, error) {
				ans := make([]string, len(qs))
				for i := range ans {
					ans[i] = pass
				}
				return ans, nil
			}),
		},
		// The tablet's host key changes with software updates, so accept whatever it presents.
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         10 * time.Second,
	}
	// Allow older algorithms too, in case the tablet runs an older Dropbear.
	sup, insec := ssh.SupportedAlgorithms(), ssh.InsecureAlgorithms()
	cfg.KeyExchanges = append(append([]string{}, sup.KeyExchanges...), insec.KeyExchanges...)
	cfg.Ciphers = append(append([]string{}, sup.Ciphers...), insec.Ciphers...)
	cfg.MACs = append(append([]string{}, sup.MACs...), insec.MACs...)
	cfg.HostKeyAlgorithms = append(append([]string{}, sup.HostKeys...), insec.HostKeys...)
	return cfg
}

func connect(host, user, pass string) (*ssh.Client, error) {
	addr := host
	if _, _, err := net.SplitHostPort(host); err != nil {
		addr = net.JoinHostPort(host, "22")
	}
	return ssh.Dial("tcp", addr, sshConfig(user, pass))
}

func friendlyConnError(err error, host string) string {
	msg := err.Error()
	switch {
	case strings.Contains(msg, "unable to authenticate") || strings.Contains(msg, "no supported methods remain"):
		return "The tablet rejected the password (or username).\n" +
			"Check the password on the tablet under Settings > General > Help > About >\n" +
			"Copyrights and licenses. It is case-sensitive, and it can change after a software update.\n" +
			"The username is normally root."
	case strings.Contains(msg, "i/o timeout") || strings.Contains(msg, "no route to host") ||
		strings.Contains(msg, "network is unreachable") || strings.Contains(msg, "connection refused") ||
		strings.Contains(msg, "connectex") || strings.Contains(msg, "timed out"):
		return fmt.Sprintf("Couldn't reach the tablet at %s.\n"+
			"  - Check the USB cable is plugged in at both ends and the tablet is switched on and unlocked.\n"+
			"  - Over USB the address is normally 10.11.99.1.\n"+
			"  - If you're using Wi-Fi instead, make sure SSH over Wi-Fi is enabled and the address is right.\n"+
			"(Technical detail: %v)", host, err)
	case strings.Contains(msg, "no such host"):
		return fmt.Sprintf("'%s' isn't a valid address. Over USB the tablet is normally 10.11.99.1.", host)
	}
	return fmt.Sprintf("Couldn't connect to the tablet: %v", err)
}

// runCmd runs a shell command on the tablet and returns combined output.
func runCmd(c *ssh.Client, cmd string) (string, error) {
	s, err := c.NewSession()
	if err != nil {
		return "", err
	}
	defer s.Close()
	var buf lockedBuffer
	s.Stdout = &buf
	s.Stderr = &buf
	err = s.Run(cmd)
	return strings.TrimSpace(buf.String()), err
}

func checkAppLoad(c *ssh.Client) error {
	out, err := runCmd(c, "if [ ! -d /home/root/xovi ]; then echo NOXOVI; elif [ ! -d "+apploadDir+" ]; then echo NOAPPLOAD; else echo OK; fi")
	if err != nil {
		return fmt.Errorf("couldn't run a check on the tablet: %v %s", err, out)
	}
	if os.Getenv("FC_DEBUG") != "" {
		fmt.Printf("DEBUG check output: %q\n", out)
	}
	switch out {
	case "OK":
		return nil
	case "NOXOVI":
		return errors.New("XOVI isn't installed on this tablet (/home/root/xovi wasn't found).\n" +
			"FourColour needs XOVI and the AppLoad extension. Install those first, then run this again.\n" +
			"Nothing was changed.")
	default:
		return errors.New("XOVI is installed, but AppLoad isn't (" + apploadDir + " wasn't found).\n" +
			"FourColour runs inside AppLoad. Install the AppLoad extension for XOVI first, then run this again.\n" +
			"Nothing was changed.")
	}
}

// ---------- install ----------

func install(c *ssh.Client) error {
	fmt.Println()
	fmt.Println("[1/4] Closing FourColour's helper if it's running and preparing folders...")
	if out, err := runCmd(c, "pkill -f 'rm-comics/backend/[e]ntry'; rm -rf "+tmpDir+" && mkdir -p "+
		tmpDir+"/backend "+appDir+"/backend "+comicsDir); err != nil {
		return fmt.Errorf("couldn't create folders: %v %s", err, out)
	}

	fmt.Println("[2/4] Copying files to the tablet...")
	if err := upload(c); err != nil {
		runCmd(c, "rm -rf "+tmpDir)
		return err
	}

	fmt.Println("[3/4] Moving files into place...")
	var mv []string
	for _, f := range files {
		mv = append(mv, fmt.Sprintf("mv -f %s/%s %s/%s", tmpDir, f.dest, appDir, f.dest))
	}
	cmd := strings.Join(mv, " && ") + " && chmod 755 " + appDir + "/backend/entry" +
		" && mkdir -p " + stateDir + " && { [ -f " + stateDir + "/install-manifest.txt ] || echo 'APPDIR " + appDir + "' > " + stateDir + "/install-manifest.txt; }" +
		"; rm -rf " + tmpDir
	if out, err := runCmd(c, cmd); err != nil {
		return fmt.Errorf("couldn't move the files into place: %v %s", err, out)
	}

	fmt.Println("[4/4] Checking the helper program runs on this tablet...")
	if out, err := runCmd(c, appDir+"/backend/entry --selftest"); err != nil {
		return fmt.Errorf("the helper's self-test failed: %v %s", err, out)
	}

	fmt.Println()
	fmt.Printf("Success! %s %s is installed.\n", appName, version)
	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Println("  1. Restart the tablet's UI with mods (for example with reManager,")
	fmt.Println("     or however you normally restart XOVI). This installer doesn't do it for you.")
	fmt.Println("  2. Open the AppLoad menu and tap FourColour.")
	fmt.Println("  3. Put .cbz/.cbr comics in " + comicsDir + " (sub-folders are fine),")
	fmt.Println("     for example by dragging them across in WinSCP.")
	return nil
}

func upload(c *ssh.Client) error {
	sc, err := sftp.NewClient(c)
	if err == nil {
		defer sc.Close()
		for _, f := range files {
			if err := sftpPut(sc, f); err != nil {
				return fmt.Errorf("copying %s failed: %v", f.dest, err)
			}
			fmt.Println("      copied", f.dest)
		}
		return nil
	}
	// No SFTP server on the tablet: fall back to streaming over a plain SSH session.
	for _, f := range files {
		if err := catPut(c, f); err != nil {
			return fmt.Errorf("copying %s failed: %v", f.dest, err)
		}
		fmt.Println("      copied", f.dest)
	}
	return nil
}

func sftpPut(sc *sftp.Client, f payloadFile) error {
	data, err := fs.ReadFile(payload, f.src)
	if err != nil {
		return err
	}
	dst := path.Join(tmpDir, f.dest)
	w, err := sc.Create(dst)
	if err != nil {
		return err
	}
	if _, err := w.Write(data); err != nil {
		w.Close()
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	if err := sc.Chmod(dst, f.mode); err != nil {
		return err
	}
	st, err := sc.Stat(dst)
	if err != nil {
		return err
	}
	if st.Size() != int64(len(data)) {
		return fmt.Errorf("size mismatch (%d of %d bytes)", st.Size(), len(data))
	}
	return nil
}

func catPut(c *ssh.Client, f payloadFile) error {
	data, err := fs.ReadFile(payload, f.src)
	if err != nil {
		return err
	}
	s, err := c.NewSession()
	if err != nil {
		return err
	}
	defer s.Close()
	dst := path.Join(tmpDir, f.dest)
	s.Stdin = bytes.NewReader(data)
	var out lockedBuffer
	s.Stdout, s.Stderr = &out, &out
	if err := s.Run(fmt.Sprintf("cat > '%s' && chmod %o '%s' && wc -c < '%s'", dst, f.mode, dst, dst)); err != nil {
		return fmt.Errorf("%v %s", err, out.String())
	}
	if strings.TrimSpace(out.String()) != fmt.Sprint(len(data)) {
		return fmt.Errorf("size mismatch (%s of %d bytes)", strings.TrimSpace(out.String()), len(data))
	}
	return nil
}

// ---------- uninstall ----------

func uninstall(c *ssh.Client) error {
	fmt.Println()
	if !yesNo("Remove the FourColour app from this tablet? Your comics in "+comicsDir+" will be kept.", false) {
		fmt.Println("Nothing was changed.")
		return nil
	}
	wipeState := yesNo("Also delete saved page positions and the cache?", false)

	cmd := "pkill -f 'rm-comics/backend/[e]ntry'; rm -rf " + appDir + " " + tmpDir
	if wipeState {
		cmd += " " + stateDir + " " + cacheDir
	} else {
		cmd += " && rm -f " + stateDir + "/install-manifest.txt"
	}
	if out, err := runCmd(c, cmd); err != nil {
		return fmt.Errorf("%v %s", err, out)
	}
	fmt.Println()
	fmt.Println("FourColour has been removed.")
	if wipeState {
		fmt.Println("Saved page positions and the cache were deleted.")
	} else {
		fmt.Println("Saved page positions were kept in " + stateDir + ".")
	}
	fmt.Println("Your comics in " + comicsDir + " were left alone.")
	fmt.Println("Restart the UI with mods (e.g. with reManager) so AppLoad stops listing FourColour.")
	return nil
}

// lockedBuffer is safe for the concurrent stdout/stderr copiers of an SSH session.
type lockedBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (l *lockedBuffer) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *lockedBuffer) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}
