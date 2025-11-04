#!/bin/bash

set -euo pipefail

# Parse arguments
APPROVE=true
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bypass)
      APPROVE=false
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

function basePrompt() {
  cat <<EOF
# Goal
I want you to generate bash for me. The bash you generate should be immediately runnable on my system (e.g. not a script).

# Tools
I have access to a number of custom built tools. You should leverage these tools in your commands if neccessary
Tools are detailed below

## llm
llm can be used to call an llm

### basic usage
\`\`\`bash
> echo "generate a python script that calculates fact(5)" | llm
def factorial(n):
    """Calculate the Factorial number at position n."""
    if n <= 1:
        return 1
    else:
        return n * factorial(n - 1)

# Calculate and print the 5th factorial
result = factorial(5)
print(result)
\`\`\`

### --schema argument
llm accepts a 'schema' argument, which can be used to generate structured output. this can be incredibly useful for code generation. you can use it in conjunction with \`jq\` to great effect. for instance,

\`\`\`bash
> llm "write a bash command that lists the files in /tmp and finds the biggest one" --schema 'bash_command string' | jq -r '.bash_command'
find /tmp -type f -exec du -h {} \; | sort -rh | head -n 1 | cut -f2
\`\`\`

#### schema syntax
JSON schema’s can be time-consuming to construct by hand. LLM also supports a concise alternative syntax for specifying a schema.

A simple schema for an object with two string properties called name and bio looks like this:

name, bio

You can include type information by adding a type indicator after the property name, separated by a space.

name, bio, age int

Supported types are int for integers, float for floating point numbers, str for strings (the default) and bool for true/false booleans.

To include a description of the field to act as a hint to the model, add one after a colon:

name: the person's name, age int: their age, bio: a short bio

#### schema with multiple outputs
You can pass in that same schema using --schema-multi and ask for several at once:

\`\`\`bash
> llm --schema-multi 'name string, age int' 'invent 3 dogs'
{"items": [{"name": "Buddy", "age": 3}, {"name": "Max", "age": 5}, {"name": "Luna", "age": 2}]}
\`\`\`

### attachments
llm accepts 'attachments'. this includes things like image files. you can use this to provide multimodal input

\`\`\`bash
> llm "where is this? one sentence answer" -a rome.jpg
This is the Colosseum in Rome, Italy.
\`\`\`

### command substitution
you can leverage command substitution to great effect, using it to 'inject' data into the prompt you feed to llm
for instance,

\`\`\`bash
> llm "\$(ls) how many files are in my current directory?"
30
\`\`\`

this is especially useful for analyzing web content

\`\`\`bash
> llm "\$(curl -s https://news.ycombinator.com/news) what is the top link on hackernews right now?"
The top link is 'At the end you use git bisect' from kevin3010.github.io
\`\`\`

## codex
codex is a coding agent developed by openai. it can write code, do research, etc.

\`\`\`bash
> codex "run the unit tests in this project. why are some of the tests failing?"
\`\`\`

i have codex configured to run with some MCP servers

$(awk '/^\[mcp_servers\./' ~/.codex/config.toml | sed 's/\[mcp_servers.//g' | tr -d ']' | sed 's/^/- /g')

the tmux MCP server is my own invention. i can use it to interact with other tmux panes in my session. for instance,

\`\`\`bash
> codex "find the tmux pane where i am SSH'd into a lambda box. look at the python traceback. what seems to be going wrong?"
\`\`\`

## chrome-ss
You can use 'chrome-ss' to generate a screenshot of a webpage

\`\`\`bash
> chrome-ss www.google.com
/tmp/screenshot-20251102-133853.png
\`\`\`

This is often used in conjunction with \`llm\`

\`\`\`bash
> SS_URL=\$(chrome-ss www.google.com)
> llm "what website is this? one sentence" -a "\$SS_URL"
This is the Google search engine homepage.
\`\`\`

## bllm
bllm generates and runs bash commands

### interactive usage
by default bllm is interactive: it requires the user to explicitly approve the command before submitting it

\`\`\`bash
> bllm "how many files are in /tmp/?"
\`\`\`bash
find /tmp/ -type f | wc -l
\`\`\`

Approve execution? [y/N] y
       20
\`\`\`

### auto usage
bllm can be instructed to run its own commands without approval using \`--bypass\`

\`\`\`bash
> bllm --bypass "how many files are in /tmp/?"
\`\`\`bash
find /tmp -type f | wc -l
\`\`\`

       20
\`\`\`


# Tips and Tricks
## Tip 1: Leverage structured outputs for great good
Structured outputs from an LLM are your best friend for complex data wrangling tasks. For instance, say I want to get the top 25 links from hackernews. Without \`llm\`, I might do something like

\`\`\`bash
> curl -s https://news.ycombinator.com/ | grep -o '<a href="http[s]\?://[^"]*"' | grep -v 'ycombinator.com' | sed 's/<a href="//;s/"$//' | head -n 10
\`\`\`

But this is brittle and hard to remember. LLM makes extracting this sort of ouput much easier. Prefer it to complex sed/grep/awk pipelines when you can.

\`\`\`bash
> llm "\$(curl -s https://news.ycombinator.com/) extract the top 25 links from hackernews" --schema-multi 'link string'
\`\`\`

## Tip 2: Partial output is ok
Sometimes you won't be able to write everything in one go. That's ok. When that happens, just leave a TODO comment at the end of your output indicating next steps.
EOF
}
PROMPT="$(basePrompt)"

# debug
#echo "$PROMPT"; exit 1

# pass any other arguments (e.g. attachments) to llm
COMMAND="$(echo "$PROMPT" | llm "${ARGS[@]}" --schema 'reasoning string, bash string' | jq -r '.bash')"

echo -e "\`\`\`bash\n$COMMAND\n\`\`\`\n"
if [[ "$APPROVE" == "true" ]]; then
  read -p "Approve execution? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Command execution cancelled."
    exit 1
  fi
fi

eval "$COMMAND"
