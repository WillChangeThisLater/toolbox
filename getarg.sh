#!/bin/bash


set -euo pipefail

# this approach is pretty cursed
#
# usage:
#
# ```bash
# node inspect $(getarg)
# ```
#
# ```bash
# node inspect $(getarg 'websocket uri')
# ```
#

get_invoke_cmd() {
    tmux capture-pane -p -S - | grep -v '^$' | cat -n | tail -n 1
}

get_terminal_out() {
    LINES=${1:-10}
    tmux capture-pane -p -S - | grep -v '^$' | cat -n | tail -n $LINES
}

get_argument() {
    PROMPT=$(cat <<EOF
    You were invoked as follows

    \`\`\`
    $(get_invoke_cmd)
    \`\`\`

    The broader terminal session you were invoked in is below:

    \`\`\`
    $(get_terminal_out)
    \`\`\`

    Your goal is to figure out the most reasonable argument for 'getarg'.
    You should use the user's prior terminal output to inform your decision.
    Usually the most reasonable argument will be a reference to something
    in stdout close by (though there are exceptions)

    For instance, if you see:

    \`\`\`
    1
    2  paul-MS-7E16% lsof -i -n -P | grep mitmproxy | grep -v grep
    3  mitmproxy 384708 paul    8u  IPv6 7556982      0t0  TCP *:8888
    4   (LISTEN)
    5  mitmproxy 384708 paul    9u  IPv4 7556983      0t0  TCP *:8888
    6   (LISTEN)
    7  paul-MS-7E16% python youtube_scrape.py --proxy "\$\(getarg\)"
    8  zsh: command not found: python
    9  paul-MS-7E16% tmux capture-pane -p -S - | cat -n
    \`\`\`

    You can tell from context that the appropriate argument is likely 'http://localhost:8888'

    If the context is unclear, use a reasonable value. For instance, if the user provides
    you only

    \`\`\`
    1 ls "\$\(getarg\)"
    \`\`\`

    You should return something reasonable, like '-la'.

    Sometimes, the user might give you hints in the argument to getarg itself.
    For instance, if you see

    \`\`\`
     2  paul-MS-7E16% ls
     3  client.js    firefox-bidi-profile  package.json       scripts
     4  debugger.js  node_modules          package-lock.json
     5  paul-MS-7E16% node "\$\(getarg 'run the client script'\)"
    \`\`\`

    You can tell from the argument to 'getarg' that the user wants you to run the client script.
    So for the argument you should return 'client.js'


    All your responses should be in JSON. Your JSON response should contain
    'argument' and 'reason'. For instance, in the proxy example above, you should return

    \`\`\`json
    {
        "argument": "http://localhost:8888",
        "reason": "user is looking for mitmproxy and likely wants to run their script using this proxy"
    }
    \`\`\`

EOF
)

    echo "$PROMPT" | llm --schema '{argument: string, reason: string}' | tee /dev/stderr | jq -r '.argument'
}

main() {
    get_argument
}

main

