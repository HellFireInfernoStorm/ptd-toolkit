#!/usr/bin/env bash
# recon.sh — THOROUGH, PORT-AGNOSTIC, evidence-friendly recon for the PTD Windows CTF.
# ---------------------------------------------------------------------------------------
# Drives every follow-up off the SERVICE nmap detects (-sV), NOT off assumed port numbers,
# so a web server on 8531 or SMB on 1445 is still found + enumerated correctly.
# Prints each command then streams its output to the TERMINAL *and* saves to loot/ (tee),
# so you can screenshot evidence straight from the terminal without re-running anything.
# Gentle timing (-T3) always — never -T5. "Thorough" adds UDP + nmap vuln scripts.
#
# Usage:   bash scripts/recon.sh <target-ip>      (or set $RHOST / run: sett <ip>)
# Modes:   MODE=gentle|balanced|thorough  (default: thorough)
# Toggles (override the mode): UDP=1/0  VULN=1/0  DIRB=1/0   (DIRB = auto quick web dir scan)
# Example: MODE=gentle UDP=0 bash scripts/recon.sh 10.10.10.10
# ---------------------------------------------------------------------------------------
set -uo pipefail

RHOST="${1:-${RHOST:-}}"
[ -z "$RHOST" ] && { echo "usage: bash scripts/recon.sh <target-ip>   (or: sett <ip>)"; exit 1; }
command -v nmap >/dev/null || { echo "[-] nmap not found — run setup.sh first."; exit 1; }

LHOST="${LHOST:-$(ip -4 route get "$RHOST" 2>/dev/null | grep -oP 'src \K[0-9.]+')}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/loot/recon-$RHOST"; mkdir -p "$OUT"
LOG="$OUT/recon.log"; SUM="$OUT/summary.txt"; : > "$SUM"

# ---- mode / toggles --------------------------------------------------------------------
MODE="${MODE:-thorough}"
case "$MODE" in
  gentle)   DO_UDP="${UDP:-0}"; DO_VULN="${VULN:-0}";;
  balanced) DO_UDP="${UDP:-1}"; DO_VULN="${VULN:-0}";;
  *)        MODE=thorough; DO_UDP="${UDP:-1}"; DO_VULN="${VULN:-1}";;
esac
DO_DIRB="${DIRB:-1}"   # auto quick directory scan on detected web ports

# ---- colors (disable with NO_COLOR=1) --------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; D=$'\033[0m'; CY=$'\033[36m'; YE=$'\033[33m'; GR=$'\033[32m'; RE=$'\033[31m'; MG=$'\033[35m'
else B=""; D=""; CY=""; YE=""; GR=""; RE=""; MG=""; fi

banner(){ printf '\n%s============================================================%s\n' "$CY" "$D" | tee -a "$LOG"
          printf '%s==  %s%s\n' "$CY" "$1" "$D" | tee -a "$LOG"
          printf '%s============================================================%s\n' "$CY" "$D" | tee -a "$LOG"; }

# run "<label>" "<shell command>"  — echoes the command, streams output to terminal + log
run(){ local label="$1" cmd="$2"
  printf '\n%s┌─[%s]%s %s%s%s\n' "$CY" "$(date +%H:%M:%S)" "$D" "$B" "$label" "$D" | tee -a "$LOG"
  printf '%s└─$ %s%s\n'           "$YE" "$cmd" "$D" | tee -a "$LOG"
  bash -c "$cmd" 2>&1 | tee -a "$LOG"; local rc=${PIPESTATUS[0]}
  printf '%s' "$D"; return $rc; }

hint(){ # $1=tag $2=text — colored to terminal, plain to log + summary
        printf '%s[HINT %s]%s %s\n' "$GR" "$1" "$D" "$2"
        printf '[HINT %s] %s\n' "$1" "$2" >> "$LOG"
        printf '[HINT %s] %s\n' "$1" "$2" >> "$SUM"; }

lc(){ printf '%s' "$1" | tr 'A-Z' 'a-z'; }

banner "RECON $RHOST   mode=$MODE  udp=$DO_UDP  vuln=$DO_VULN  dirb=$DO_DIRB   LHOST=${LHOST:-?}"
echo "  Output dir: $OUT   (full transcript: recon.log)" | tee -a "$LOG"
[ "$DO_VULN" = 1 ] && printf '  %s[!] vuln scripts ON — more active probing (you chose thorough).%s\n' "$RE" "$D"

# =======================================================================================
# PHASE 1 — full TCP port discovery (all 65535)
# =======================================================================================
banner "PHASE 1 — TCP port discovery (all ports, -T3)"
run "full TCP sweep" "nmap -Pn -n -T3 -p- --open -oA '$OUT/tcp-allports' '$RHOST'"
PORTS="$(grep -oE '[0-9]+/open/tcp' "$OUT/tcp-allports.gnmap" 2>/dev/null | cut -d/ -f1 | sort -un | paste -sd, -)"
echo "${B}Open TCP ports:${D} ${PORTS:-none}" | tee -a "$LOG"

# =======================================================================================
# PHASE 2 — service/version + default scripts on the open ports (+ OS if root)
# =======================================================================================
if [ -n "$PORTS" ]; then
  banner "PHASE 2 — service & version detection"
  OSF=""; [ "$(id -u)" = 0 ] && OSF="-O"
  run "version + default scripts" \
    "nmap -Pn -n -T3 -sV -sC $OSF --version-all -p $PORTS -oA '$OUT/tcp-services' '$RHOST'"
else
  echo "${RE}[-] No open TCP ports (firewall default-deny?). Continuing to UDP...${D}" | tee -a "$LOG"
fi

# =======================================================================================
# PHASE 3 — UDP top ports (SNMP/TFTP/DNS often sit here, sometimes on odd ports)
# =======================================================================================
if [ "$DO_UDP" = 1 ]; then
  banner "PHASE 3 — UDP top-100 (slower; catches SNMP/TFTP/DNS)"
  if [ "$(id -u)" = 0 ]; then
    run "UDP top-100" "nmap -Pn -n -T3 -sU --top-ports 100 --open -oA '$OUT/udp-top' '$RHOST'"
  else
    run "UDP top-100 (sudo)" "sudo -n nmap -Pn -n -T3 -sU --top-ports 100 --open -oA '$OUT/udp-top' '$RHOST' || echo '[-] UDP scan needs root; run:  sudo MODE=$MODE bash scripts/recon.sh $RHOST'"
  fi
fi

# =======================================================================================
# PHASE 4 — per-service enumeration, searchsploit, and exploitation HINTS (port-agnostic)
# =======================================================================================
banner "PHASE 4 — per-service enumeration + exploit hints"

WL_SMALL="/usr/share/wordlists/dirb/common.txt"
[ -f "$WL_SMALL" ] || WL_SMALL="/usr/share/seclists/Discovery/Web-Content/common.txt"

enum_service(){ # $1=port $2=proto $3=service $4=version
  local port="$1" proto="$2" svc="$3" ver="$4" low tag scheme
  low="$(lc "$svc $ver")"
  echo "$port/$proto  $svc  ${ver:-?}" >> "$SUM"

  # ---- classify by SERVICE (not port) ----
  tag=other; scheme=http
  case "$low" in
    *microsoft\ httpapi*|*wsman*)              tag=winrm;;
    *ssl/http*|*https*|*http*\ ssl*)           tag=http; scheme=https;;
    *http*)                                    tag=http; scheme=http;;
    *microsoft-ds*|*netbios-ssn*|*\ smb*|smb*) tag=smb;;
    *ftp*)                                     tag=ftp;;
    *ms-wbt-server*|*rdp*|*remote\ desktop*)   tag=rdp;;
    *ms-sql*|*mssql*)                          tag=mssql;;
    *mysql*|*mariadb*)                         tag=mysql;;
    *ssh*)                                     tag=ssh;;
    *snmp*)                                    tag=snmp;;
    *ldap*)                                    tag=ldap;;
    *smtp*)                                    tag=smtp;;
    *telnet*)                                  tag=telnet;;
    *vnc*)                                     tag=vnc;;
    *)                                         tag=other;;
  esac
  # port-based overrides for services that masquerade as http
  case "$port" in 5985|5986) tag=winrm;; esac

  printf '\n%s### %s/%s  →  %s  [%s]  %s%s\n' "$MG" "$port" "$proto" "${svc:-?}" "$tag" "${ver:-}" "$D" | tee -a "$LOG"

  # ---- offline searchsploit on the version (gentle: local DB, no target traffic) ----
  if command -v searchsploit >/dev/null && [ -n "$ver" ]; then
    local q; q="$(printf '%s' "$ver" | awk '{print $1, $2}' | tr -cd 'A-Za-z0-9 .+-')"
    [ -n "$q" ] && run "searchsploit $q" "searchsploit $q 2>/dev/null | grep -v 'No Results' || echo '(no local exploits — try the service name / Google AI Mode)'"
  fi

  case "$tag" in
    http)
      local url="$scheme://$RHOST:$port"
      command -v whatweb >/dev/null && run "whatweb $url" "whatweb -a3 '$url' 2>/dev/null"
      run "headers + robots.txt" "curl -sSIk --max-time 15 '$url' ; echo '--- robots ---' ; curl -sSk --max-time 15 '$url/robots.txt'"
      run "nmap http scripts :$port" "nmap -Pn -n -T3 -p $port --script 'http-title,http-headers,http-methods,http-enum,http-robots.txt,http-webdav-scan' -oN '$OUT/http-$port.nmap' '$RHOST'"
      [ "$DO_VULN" = 1 ] && run "nmap http-vuln :$port" "nmap -Pn -n -T3 -p $port --script 'http-vuln*,http-shellshock,http-sql-injection' -oN '$OUT/http-vuln-$port.nmap' '$RHOST'"
      if [ "$DO_DIRB" = 1 ] && command -v gobuster >/dev/null; then
        run "quick gobuster :$port (common.txt -t 10)" "gobuster dir -u '$url' -w '$WL_SMALL' -t 10 -x php,txt,html,asp,aspx -q -o '$OUT/gobuster-$port.txt' 2>/dev/null; echo '--- hits ---'; cat '$OUT/gobuster-$port.txt' 2>/dev/null"
      fi
      hint "WEB:$port" "Browse $url . DEEPER dirs:  gobuster dir -u $url -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -t 10 -x php,txt,html,asp,aspx"
      hint "WEB:$port" "Param fuzz:  ffuf -w /usr/share/seclists/Discovery/Web-Content/common.txt -u '$url/PAGE?FUZZ=x' -fs <size> . If it redirects to a hostname → add it to /etc/hosts. See cheatsheets 02/03."
      ;;
    smb)
      command -v smbclient >/dev/null && run "SMB shares (null) :$port" "smbclient -L //$RHOST -N -p $port 2>&1"
      command -v smbmap   >/dev/null && run "smbmap R/W :$port" "smbmap -H $RHOST -P $port 2>/dev/null"
      command -v nxc      >/dev/null && run "nxc smb shares" "nxc smb $RHOST -u '' -p '' --shares 2>/dev/null"
      [ "$port" = 445 ] && command -v enum4linux-ng >/dev/null && run "enum4linux-ng -A" "enum4linux-ng -A $RHOST 2>/dev/null | sed -n '1,120p'"
      run "nmap smb scripts :$port" "nmap -Pn -n -T3 -p $port --script 'smb-os-discovery,smb-enum-shares,smb-enum-users,smb-security-mode,smb2-security-mode' -oN '$OUT/smb-$port.nmap' '$RHOST'"
      [ "$DO_VULN" = 1 ] && run "nmap smb-vuln :$port" "nmap -Pn -n -T3 -p $port --script 'smb-vuln*' -oN '$OUT/smb-vuln-$port.nmap' '$RHOST'"
      hint "SMB:$port" "Read every anon share (easy flag often here):  smbclient //$RHOST/<Share> -N -p $port  → ls / get / mget *. Writable share = payload drop. See cheatsheets 02 §1."
      ;;
    ftp)
      run "nmap ftp scripts :$port" "nmap -Pn -n -T3 -p $port --script 'ftp-anon,ftp-syst' -oN '$OUT/ftp-$port.nmap' '$RHOST'"
      hint "FTP:$port" "Anon login:  ftp $RHOST $port  (anonymous/anonymous). Mirror:  wget -r ftp://anonymous:anonymous@$RHOST:$port/ . Writable + auto-exec folder = foothold (cheatsheet 02 §2)."
      ;;
    rdp)
      run "nmap rdp-ntlm-info :$port" "nmap -Pn -n -T3 -p $port --script 'rdp-ntlm-info,rdp-enum-encryption' -oN '$OUT/rdp-$port.nmap' '$RHOST'"
      hint "RDP:$port" "With creds:  xfreerdp3 /u:<user> /p:'<pass>' /v:$RHOST:$port /cert:ignore   (toolkit:  rdp <user> <pass> $port)"
      ;;
    winrm)
      hint "WINRM:$port" "With creds → the Windows money shell:  evil-winrm -i $RHOST -u <user> -p '<pass>' -P $port   (toolkit:  winrm <user> <pass> $port). Then: whoami /priv → cheatsheet 04."
      ;;
    mssql)
      run "nmap mssql scripts :$port" "nmap -Pn -n -T3 -p $port --script 'ms-sql-info,ms-sql-ntlm-info,ms-sql-empty-password' -oN '$OUT/mssql-$port.nmap' '$RHOST'"
      hint "MSSQL:$port" "With creds:  impacket-mssqlclient <u>:'<p>'@$RHOST -p $port   OR  sqsh -S $RHOST:$port -U <u> -P '<p>'  → EXEC xp_cmdshell 'whoami'. SQL svc acct usually has SeImpersonate → potato (cheatsheet 04 §1/§7)."
      ;;
    mysql)
      run "nmap mysql scripts :$port" "nmap -Pn -n -T3 -p $port --script 'mysql-info,mysql-empty-password,mysql-enum' -oN '$OUT/mysql-$port.nmap' '$RHOST'"
      hint "MYSQL:$port" "With creds:  mysql -h $RHOST -P $port -u <u> -p   → dump creds / read files. searchsploit the version above."
      ;;
    ssh)
      run "nmap ssh scripts :$port" "nmap -Pn -n -T3 -p $port --script 'ssh-auth-methods,ssh2-enum-algos,ssh-hostkey' -oN '$OUT/ssh-$port.nmap' '$RHOST'"
      hint "SSH:$port" "Note the version (searchsploit above). With creds:  ssh <user>@$RHOST -p $port . Rare on a Windows box but possible."
      ;;
    snmp)
      command -v snmpwalk >/dev/null && run "snmpwalk public :$port" "snmpwalk -c public -v1 -r 1 -t 3 $RHOST 2>/dev/null | sed -n '1,60p'"
      hint "SNMP:$port" "community 'public' leaks users/processes/installed sw:  snmpwalk -c public -v1 $RHOST . Windows users OID: 1.3.6.1.4.1.77.1.2.25"
      ;;
    smtp)
      run "nmap smtp scripts :$port" "nmap -Pn -n -T3 -p $port --script 'smtp-commands,smtp-enum-users,smtp-open-relay' -oN '$OUT/smtp-$port.nmap' '$RHOST'"
      hint "SMTP:$port" "Enumerate users (VRFY/EXPN/RCPT). Usernames feed a gentle, targeted password spray only."
      ;;
    ldap)
      run "nmap ldap scripts :$port" "nmap -Pn -n -T3 -p $port --script 'ldap-rootdse,ldap-search' -oN '$OUT/ldap-$port.nmap' '$RHOST'"
      hint "LDAP:$port" "rootDSE leaks the domain naming context. ldapsearch -x -H ldap://$RHOST:$port -s base"
      ;;
    telnet) hint "TELNET:$port" "telnet $RHOST $port — grab the banner; try found creds.";;
    vnc)    hint "VNC:$port" "With a password:  vncviewer $RHOST:$port . searchsploit the version above.";;
    *)      hint "OTHER:$port" "Unrecognised service '${svc:-?}'. searchsploit it (above), grab the banner:  nc -nv $RHOST $port  /  curl -sv $RHOST:$port . Check Google AI Mode for '$svc $ver exploit'.";;
  esac
}

# ---- parse the -sV results (gnmap) and enumerate each service, port-agnostically --------
parse_and_enum(){ local gnmap="$1" proto="$2"
  [ -f "$gnmap" ] || return 0
  # Ports field entries look like:  80/open/tcp//http//Apache httpd 2.4.41/
  sed -n 's/.*Ports: //p' "$gnmap" | tr ',' '\n' | while IFS= read -r e; do
    e="$(printf '%s' "$e" | sed 's/^ *//')"
    [ -z "$e" ] && continue
    case "$e" in */open/*) ;; *) continue;; esac
    local port svc ver
    port="$(printf '%s' "$e" | cut -d/ -f1)"
    svc="$( printf '%s' "$e" | cut -d/ -f5)"
    ver="$( printf '%s' "$e" | cut -d/ -f7 | sed 's/|/ /g; s/ *$//')"
    enum_service "$port" "$proto" "$svc" "$ver"
  done
}
# process substitution would be cleaner but gnmap-per-line keeps ordering; run in-shell:
if [ -f "$OUT/tcp-services.gnmap" ]; then parse_and_enum "$OUT/tcp-services.gnmap" tcp
elif [ -n "$PORTS" ]; then  # services scan skipped but ports exist — enumerate by port guess
  for p in ${PORTS//,/ }; do enum_service "$p" tcp "unknown" ""; done
fi
[ -f "$OUT/udp-top.gnmap" ] && parse_and_enum "$OUT/udp-top.gnmap" udp

# =======================================================================================
# SUMMARY
# =======================================================================================
banner "SUMMARY — $RHOST"
echo "${B}Services found:${D}" | tee -a "$LOG"
grep -E '^[0-9]+/(tcp|udp)' "$SUM" 2>/dev/null | sort -n | sed 's/^/  /' | tee -a "$LOG"
echo | tee -a "$LOG"
echo "${B}Exploit hints (also saved in summary.txt):${D}" | tee -a "$LOG"
grep -E '^\[HINT' "$SUM" 2>/dev/null | sed 's/^/  /' | tee -a "$LOG"
echo | tee -a "$LOG"
echo "${GR}Next:${D} pick a foothold → cheatsheets/02-foothold.md ; get a shell on 4444 (l4) ; then whoami /priv → 04-win-privesc.md" | tee -a "$LOG"
echo "${GR}Evidence:${D} full transcript in  $LOG   (per-service nmap in $OUT/*.nmap)" | tee -a "$LOG"
