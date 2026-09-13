## How to use these

### Debug
You need to be using tmux for this to work

```bash
[arch@archlinux chess]$ pacman -Sy netutils
error: you cannot perform this operation unless you are root.
[arch@archlinux chess]$ debug
Debugging. It might take 10-15 seconds for a response to appear
If you think the prompt is wrong check /tmp/prompt.txt"
If you want to change the prompt check ~/.bashrc

The most recent error in the session is:

error: you cannot perform this operation unless you are root.

This error occurs because the `pacman` command, which is used for package management in Arch Linux, requires root privileges to install or update packages.

To resolve this error, follow these steps:

1. **Run the command with superuser privileges:**
   You need to execute the `pacman` command with `sudo` to obtain the necessary root permissions. Try the following command:

   sudo pacman -Sy netutils

2. **Authenticate:**
   You will be prompted to enter your password to authenticate as a superuser. Type your password and press `Enter`.

3. **Installation:**
   If the password is correct and you have the necessary permissions, the package `netutils` will be installed or updated.

If you encounter any additional errors, check the output for specific messages and follow the instructions provided or consult the Arch Linux documentation or community for further assistance.
```

### Download Site
I use this a lot for long plane rides where I'm not sure I'll have wifi

```bash
./download-site.sh https://eli.thegreenplace.net/ # tweak the script settings to make sure you dont clobber the site
```

### Markdown
I use this to create CLI prompts.

```bash
#!/bin/bash

source ~/.bashrc # where ~/.bashrc runs an eval on markdown.sh
cat <<EOF
Explain how the following command works:

$(bash_markdown "ls | wc")
EOF
```

### Netutils
There are a couple functions in here.
The implementation of cidrrange is gross.

```bash
[arch@archlinux shell-scripts]$ eval "$(./netutils.sh)"
[arch@archlinux shell-scripts]$ cidrrange 10.0.0.1/28
10.0.0.0
10.0.0.1
10.0.0.2
10.0.0.3
10.0.0.4
10.0.0.5
10.0.0.6
10.0.0.7
10.0.0.8
10.0.0.9
10.0.0.10
10.0.0.11
10.0.0.12
10.0.0.13
10.0.0.14
10.0.0.15
[arch@archlinux shell-scripts]$ incidr 10.0.1.0 10.0.0.1/28
no
```

### Remote setup
This is a weird one. It leverages some tricks with declare to
perform setup on a remote machine/container

There's probably some less hacky way of doing this but this way
seems to work.

```bash
[arch@archlinux shell-scripts]$ docker run -it ubuntu /bin/sh -c "$(./remote-setup.sh)"
Detected APT package manager
/usr/bin/apt-get
Get:1 http://archive.ubuntu.com/ubuntu noble InRelease [256 kB]
Fetched 26.6 MB in 8s (3176 kB/s)
Reading package lists... Done
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  ca-certificates krb5-locales libbrotli1 libcurl4t64 libexpat1 libgpm2 libgssapi-krb5-2 libk5crypto3 libkeyutils1 libkrb5-3
  libkrb5support0 libldap-common libldap2 libnghttp2-14 libpsl5t64 libpython3.12-minimal libpython3.12-stdlib libpython3.12t64
  libreadline8t64 librtmp1 libsasl2-2 libsasl2-modules libsasl2-modules-db libsodium23 libsqlite3-0 libssh-4 media-types netbase
  openssl publicsuffix readline-common tzdata vim-common vim-runtime xxd
Suggested packages:
  gpm krb5-doc krb5-user libsasl2-modules-gssapi-mit | libsasl2-modules-gssapi-heimdal libsasl2-modules-ldap libsasl2-modules-otp
  libsasl2-modules-sql readline-doc ctags vim-doc vim-scripts
The following NEW packages will be installed:
  ca-certificates curl krb5-locales libbrotli1 libcurl4t64 libexpat1 libgpm2 libgssapi-krb5-2 libk5crypto3 libkeyutils1 libkrb5-3
  libkrb5support0 libldap-common libldap2 libnghttp2-14 libpsl5t64 libpython3.12-minimal libpython3.12-stdlib libpython3.12t64
  libreadline8t64 librtmp1 libsasl2-2 libsasl2-modules libsasl2-modules-db libsodium23 libsqlite3-0 libssh-4 media-types netbase
  openssl publicsuffix readline-common tzdata vim vim-common vim-runtime wget xxd
0 upgraded, 38 newly installed, 0 to remove and 10 not upgraded.
Need to get 20.2 MB of archives.
After this operation, 82.2 MB of additional disk space will be used.
... # tons of setup happens here
Using shell /bin/sh
# which vi
/usr/bin/vi
```

### Share
I use this to share files over local networks

Server:
```bash
[arch@archlinux shell-scripts]$ ifconfig wlan0
wlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.1.170  netmask 255.255.255.0  broadcast 192.168.1.255

[arch@archlinux shell-scripts]$ ./share.sh .
Serving files from .
shell-scripts/
shell-scripts/download-site.sh
shell-scripts/simple-server.sh
shell-scripts/slink.sh
shell-scripts/netutils.sh
shell-scripts/transcribe.sh
shell-scripts/markdown.sh
shell-scripts/debug.sh
shell-scripts/remote-setup.sh
shell-scripts/README.md
shell-scripts/share.sh
Serving HTTP on 0.0.0.0 port 8080 (http://0.0.0.0:8080/) ...
```

Client:
```bash
[arch@archlinux out]$ curl 192.168.1.170:8080/shell-scripts.tar.gz -o shell-scripts.tar.gz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  6886  100  6886    0     0  1319k      0 --:--:-- --:--:-- --:--:-- 1681k
[arch@archlinux out]$ tar -xvf shell-scripts.tar.gz
shell-scripts/
shell-scripts/download-site.sh
shell-scripts/simple-server.sh
shell-scripts/slink.sh
shell-scripts/netutils.sh
shell-scripts/transcribe.sh
shell-scripts/markdown.sh
shell-scripts/debug.sh
shell-scripts/remote-setup.sh
shell-scripts/README.md
shell-scripts/share.sh
[arch@archlinux out]$ ls
shell-scripts  shell-scripts.tar.gz
```

### Simple server
I used this for web dev sometimes

```bash
[arch@archlinux shell-scripts]$ echo "<p>hello there!</p>" | ./simple-server.sh
-bash: !: event not found
[arch@archlinux shell-scripts]$ echo "<p>hello there\!</p>" | ./simple-server.sh &
[1] 3846377
[arch@archlinux shell-scripts]$ Serving HTTP on ::1 port 8000 (http://[::1]:8000/) ...
curl localhost:8000
::1 - - [30/Nov/2024 10:59:48] "GET / HTTP/1.1" 200 -
<p>hello there\!</p>
[arch@archlinux shell-scripts]$ kill -9 3846377
[1]+  Killed                  echo "<p>hello there\!</p>" | ./simple-server.sh
```

### slink
I used this for symlinking scripts to my local system
Apparently you can also use [GNU Stow](https://www.gnu.org/software/stow/) for this

```bash
[arch@archlinux shell-scripts]$ which share
which: no share in (/home/arch/.local/bin:/home/arch/.local/bin:/home/arch/.pyenv/plugins/pyenv-virtualenv/shims:/home/arch/.pyenv/shims:/home/arch/.local/bin:/home/arch/.pyenv/plugins/pyenv-virtualenv/shims:/home/arch/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/lib/emscripten:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:/usr/lib/emscripten)
[arch@archlinux shell-scripts]$ sudo slink share.sh
[sudo] password for arch:
ln -s /home/arch/scripts/shell-scripts/share.sh /usr/local/bin/share
[arch@archlinux shell-scripts]$ which share
/usr/local/bin/share
```

### Webshot
A script to take screenshots of specific URLs using the [pyppeteer](https://github.com/pyppeteer/pyppeteer) library.

#### Requirements
- Python 3.9 or higher
- pyppeteer

#### Usage
```bash
./webshot.py --url <URL> [--path <PATH>] [--fullpage]
```

- `--url` : The URL of the webpage to screenshot
- `--path` : (Optional) The path to save the screenshot
- `--fullpage` : (Optional) Whether to take a full-page screenshot

If the `--path` is not specified, the screenshot will be printed as a base64 data URL.

### STT
One-shot speech-to-text using whisper.cpp. Record from the mic or transcribe a
file; the transcript goes to stdout, nothing else (diagnostics -> stderr), so
it pipes cleanly.

#### Requirements
- whisper-cli on PATH and a ggml model in ~/.pi/agent/models/ (see `stt --list-models`)
- arecord (mic mode), ffmpeg (non-wav input), jq (--json)

#### Usage
```bash
stt                       # record from mic until Enter, transcript to stdout
stt recording.mp3         # transcribe a file
stt - | wc -w             # or read 16k mono s16le PCM from stdin
stt -w peacock note.wav   # stop word: truncate before it, exit code 10
stt --json file.wav       # {text, elapsed, audio_seconds, rt_factor, stopped}
```

Options: `-m MODEL`, `-o FILE`, `-w WORDS`, `--json`, `--list-models`.
Optional flat-YAML config at `~/.config/stt/config.yaml` (model, backend,
stop_words) or via `$STT_CONFIG`. Exit codes: 0 ok, 1 error, 2 no speech, 10
stop word hit.

Tests (uses the whisper.cpp jfk.wav sample + the fast tiny.en model):
```bash
tests/stt/run.sh   # fetch tests/stt/fixtures/jfk.wav first if missing
```
