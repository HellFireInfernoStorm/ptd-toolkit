# 01 — Recon & Enumeration (gentle)

Vars: `$RHOST` target, `$LHOST` Kali. **No `-T5`, no `-A` blasting at the start.** Slow = unblacklisted.

## Port scan (two-step, quiet)
```bash
# 1) all ports, slow, no DNS/ping noise
nmap -Pn -n -T2 -p- --open -oN loot/nmap-allports.txt $RHOST
# 2) version + default scripts on ONLY the open ports (comma-separated)
nmap -Pn -n -T2 -sV -sC -p 21,80,139,445,3389,<etc> -oN loot/nmap-services.txt $RHOST
# UDP (quick, common only — SNMP/DNS live here):
sudo nmap -Pn -n -sU -T2 --top-ports 20 -oN loot/nmap-udp.txt $RHOST
```
`-Pn` skip ping · `-n` no DNS · `-T2` polite · `--open` only open ports. Record EVERY port+version.

## Per-service enumeration (pick by what's open)

### SMB — 139/445  (⭐ common easy-flag source)
```bash
smbclient -L //$RHOST -N                      # list shares, null session
smbclient //$RHOST/<Share> -N                 # connect anon; then: ls, get <file>, put <file>
#   inside smbclient:  recurse ON; prompt OFF; mget *     (grab everything)
enum4linux-ng -A $RHOST                        # users, shares, OS, password policy
nxc smb $RHOST -u '' -p '' --shares           # netexec (crackmapexec) null-session shares
nxc smb $RHOST -u guest -p '' --shares
rpcclient -U "" -N $RHOST                      # then: enumdomusers, querydispinfo
```

### FTP — 21  (⭐ anon read/write)
```bash
ftp -n $RHOST            # then:  user anonymous anonymous   (or 'ftp'/blank)
#   ls -la ; binary ; get Flag_Easy.txt ; get .bash_history
#   writable? ->  put <payload>      (then trigger it, see 04/05)
curl -s "ftp://anonymous:anonymous@$RHOST/" --list-only   # quick listing
```

### HTTP — 80 / any high port  (⭐ web foothold)
```bash
whatweb http://$RHOST:<port>/                              # tech/version fingerprint
curl -s http://$RHOST:<port>/ | head -50                   # and VIEW SOURCE (Ctrl+U) for comments!
curl -s http://$RHOST:<port>/robots.txt
curl -s http://$RHOST:<port>/sitemap.xml                   # <-- paths gobuster misses (Tut10)
gobuster dir -u http://$RHOST:<port>/ -w /usr/share/wordlists/dirb/common.txt -t 4 \
  -x php,txt,html,json -o loot/gobuster-<port>.txt         # -t 4 = gentle
# API-ish? recurse into what you find:
gobuster dir -u http://$RHOST:<port>/api/internal/ -w /usr/share/wordlists/dirb/common.txt -x json -t 4
```
Look for: login forms, upload, admin panels, `/api/*`, template params (SSTI), "Run/Save" controls.

### RDP — 3389
```bash
nmap -p3389 --script rdp-ntlm-info $RHOST          # hostname/domain leak
xfreerdp /u:<user> /p:'<pass>' /v:$RHOST /cert:ignore +clipboard    # once you have creds
```

### MSSQL — 1433  /  MySQL — 3306
```bash
nmap -p1433 --script ms-sql-info,ms-sql-ntlm-info $RHOST
sqsh -S $RHOST -U <user> -P '<pass>'               # MSSQL shell (xp_cmdshell -> see 04)
impacket-mssqlclient <user>:'<pass>'@$RHOST        # alternative
```

### SNMP — 161/udp
```bash
snmpwalk -v2c -c public $RHOST                      # whole tree (noisy-ish; grep it)
snmpwalk -v2c -c public $RHOST 1.3.6.1.4.1.77.1.2.25   # users
snmp-check $RHOST -c public
```

### WinRM — 5985 / 5986   (foothold once you have creds)
```bash
nxc winrm $RHOST -u <user> -p '<pass>'
evil-winrm -i $RHOST -u <user> -p '<pass>'          # interactive PowerShell
```

### Other / unknown service port
```bash
nc -nv $RHOST <port>                                # banner grab (type a line, hit enter)
searchsploit <product> <version>                    # public exploit? (MSF one-use candidate)
searchsploit -m <path>                              # copy an exploit locally
```

## Quick exploit lookup
```bash
searchsploit <product> <version>         # offline Exploit-DB
# non-GenAI web allowed: exploit-db.com, packetstormsecurity, vendor advisories, GTFOBins, LOLBAS
```

## Gotchas
- The **web app is often on a high random port** — scan `-p-`, don't stop at 80/443.
- Always try **null/anon** first (SMB `-N`, FTP anonymous) — free easy flags.
- **View page source + robots + sitemap.xml** — usernames/paths hide in comments & XML.
- Keep `-t 4` on gobuster and `-T2` on nmap. Note findings in `loot/` as you go (report evidence).
