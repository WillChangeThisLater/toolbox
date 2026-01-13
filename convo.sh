#!/bin/bash

set -euo pipefail

usage() {
	echo "Usage: script.sh [options] [\"YOUR QUESTION HERE\"]"
	echo "Options:"
	echo "  -p PANE    Pane to target."
	echo "  -l LIMIT   The number of lines to capture from the tmux pane."
	echo "  -d         Debug flag (print the llm prompt to stdout instead of calling llm)"
	echo "  -h         Show this help message and exit."
	echo "  -g         Pipe output through 'glow'"
	echo "  -e         (exec) bash command"
}

# Default values
DEFAULT_PROMPT="$"
DEFAULT_LIMIT=500

# Initialize variables with default values
PROMPT="$DEFAULT_PROMPT"
LIMIT="$DEFAULT_LIMIT"
PANE_TARGET=""
DEBUG=false
GLOW=false
EXEC_CMD=false

# Parse command-line options
while getopts ":p:l:edgh" opt; do
 case $opt in
 s) PROMPT="$OPTARG" ;; # "shell" prompt (note: -s isn't in optstring but kept for compatibility)
  p) PANE_TARGET="$OPTARG" ;;
	l) LIMIT="$OPTARG" ;;
	d) DEBUG=true ;;
	e) EXEC_CMD=true ;;
	g) GLOW=true ;;
	h)
		usage
		exit 0
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		usage
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		usage
		exit 1
		;;
	esac
done

shift $((OPTIND - 1))

capture_context_current_pane() {
	tmux capture-pane -p -S - | sed '$d' | tail -n "$LIMIT"
}

capture_context_from_pane() {
	tmux capture-pane -p -S - -t "$1" | tail -n "$LIMIT"
}

capture_context() {
	if [[ -n "$PANE_TARGET" ]]; then
		capture_context_from_pane "$PANE_TARGET"
	else
		capture_context_current_pane
	fi
}

respond() {
	local user_input=""

	if (($# > 0)); then
		user_input="$1"
		shift || true
	fi

	local twice_limit=$((LIMIT * 2))

	generate_payload() {
		cat <<-EOF
			    # instructions
			    ## context
			    you are answering about a terminal session. you can only see the last $LIMIT lines:
			    
			    \`\`\`
			    $(capture_context)
			    \`\`\`
		EOF

		if [[ -n "$user_input" ]]; then
			cat <<-EOF
				## user request (may be a question, instruction, or task)
				\`\`\`
				${user_input}
				\`\`\`
			EOF
		fi

               cat <<-EOF
                       ## context handling tips
                       - treat the captured history as authoritative; review it before deciding anything is missing.
                       - if the user question mentions a command, output, or file, look for that exact content in the captured session and refer to what you find before falling back.
                       - whenever you see diagnostic text (errors, warnings, help text, etc.) that matches the user's ask, mention and explain it clearly in your response so the user knows you read it.
                       - repeated references like "see the output above" or "how can this be improved" should prompt you to use the most recent relevant lines instead of reissuing the fallback line.
		EOF

		cat <<-EOF
			## response format
			- prefer markdown for formatting long form responses
			- be clear and concise; prioritize the answer/deliverable over explanation.
			- keep output terminal-friendly (avoid very long lines).
			- for complex answers, add short section headers for quick scanning.
			- only give information that is relevant to the question/instruction/task

			## how to answer
			### most important: anticipate what the user really wants
			think about what the user really wants from this response, and tailor your output to match that. for instance:

			- if the user asks for a quick bash script for finding the top ten files in each directory, they probably want just the script. if they are confused by the script and want you to explain it, they will ask you later
			- if the user is asking a complicated question, they probably want a longer form output, which means you should probably output the result in markdown since that's nicer to read.
			- if the user sends you a traceback or error they want you to debug, they're probably looking for actionable steps they can take to debug the issue

			### debugging & errors
			- state the **root cause first**, then the solution.
			- provide **ready-to-run fix commands** when appropriate.
			- for python tracebacks, highlight the **most relevant line** and explain it.

			### shell commands
			- show a **minimal working example** first, then advanced usage.
			- briefly explain pipeline components when helpful.

			### code generation / tasks
			- produce **complete, runnable snippets** with brief comments.
			- prefer **portable** approaches (posix sh/portable python) when feasible.
			- if generating a script for parameters (e.g., *arg1* and *arg2*), include a **usage example**.

			### data manipulation
			- prefer efficient **one-liners** (awk/sed/jq) for simple tasks.
			- use short scripts for complex tasks.

			## style guide
			- be direct and practical
			- assume technical competence but don’t skip crucial steps.
			- use precise language

			## error cases
			### when the question is too vague
			if the user asks a vague question you don't understand, ask for clarification

			### when something is not visible
			the terminal session you see is truncated to the last $LIMIT lines of output. this happens rarely, but sometimes the user will reference something (usually the output of a command) which occurred more than $LIMIT lines ago. when this happens, output **exactly one line and nothing else**, using this template. you should replace {{ thing }} with a short noun phrase and the number with $twice_limit.

			for instance:

			\`\`\`
			I can't see the {{ thing }} you're referring to. Make sure you're running me in the right pane, or try calling me again with \`convo -l $twice_limit\` to provide more context
			\`\`\`

			- choose {{ thing }} from the user's request (e.g., "python traceback", "error message", "build log").

		EOF
		cat <<-EOF
		## writing commands
		in the event that you are explicitly asked to write a command: there are a number of built ins available on the system

                ### llm
                llm can be used to call an llm
                
                #### basic usage
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
                
                #### --schema argument
                llm accepts a 'schema' argument, which can be used to generate structured output. this can be incredibly useful for code generation. you can use it in conjunction with \`jq\` to great effect. for instance,
                
                \`\`\`bash
                > llm "write a bash command that lists the files in /tmp and finds the biggest one" --schema 'bash_command string' | jq -r '.bash_command'
                find /tmp -type f -exec du -h {} \; | sort -rh | head -n 1 | cut -f2
                \`\`\`
                
                ##### schema syntax
                JSON schema’s can be time-consuming to construct by hand. LLM also supports a concise alternative syntax for specifying a schema.
                
                A simple schema for an object with two string properties called name and bio looks like this:
                
                name, bio
                
                You can include type information by adding a type indicator after the property name, separated by a space.
                
                name, bio, age int
                
                Supported types are int for integers, float for floating point numbers, str for strings (the default) and bool for true/false booleans.
                
                To include a description of the field to act as a hint to the model, add one after a colon:
                
                name: the person's name, age int: their age, bio: a short bio
                
                ##### schema with multiple outputs
                You can pass in that same schema using --schema-multi and ask for several at once:
                
                \`\`\`bash
                > llm --schema-multi 'name string, age int' 'invent 3 dogs'
                {"items": [{"name": "Buddy", "age": 3}, {"name": "Max", "age": 5}, {"name": "Luna", "age": 2}]}
                \`\`\`
                
                #### attachments
                llm accepts 'attachments'. this includes things like image files. you can use this to provide multimodal input
                
                \`\`\`bash
                > llm "where is this? one sentence answer" -a rome.jpg
                This is the Colosseum in Rome, Italy.
                \`\`\`
                
                #### command substitution
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
                
                ### codex
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
                
                ### chrome-ss
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
                
                ## general tips and tricks for writing commands
                ### tip 1:lLeverage structured outputs for great good
                Structured outputs from an LLM are your best friend for complex data wrangling tasks. For instance, say I want to get the top 25 links from hackernews. Without \`llm\`, I might do something like
                
                \`\`\`bash
                > curl -s https://news.ycombinator.com/ | grep -o '<a href="http[s]\?://[^"]*"' | grep -v 'ycombinator.com' | sed 's/<a href="//;s/"$//' | head -n 10
                \`\`\`
                
                But this is brittle and hard to remember. LLM makes extracting this sort of ouput much easier. Prefer it to complex sed/grep/awk pipelines when you can.
                
                \`\`\`bash
                > llm "\$(curl -s https://news.ycombinator.com/) extract the top 25 links from hackernews" --schema-multi 'link string'
                \`\`\`
		EOF
	}
    if [[ "$DEBUG" == true ]]; then
        generate_payload
        return
    fi

    if (($# > 0)); then
        generate_payload | llm "$@"
    else
        generate_payload | llm
    fi
}

# Dispatch
post_processors() {
	if [[ "$GLOW" == true ]]; then
		glow --width 0
	elif [[ "$EXEC_CMD" == true ]]; then
		COMMAND="$(cat | llm "extract the bash command. this command should be immediately runnable in my terminal" --schema "command string" | jq -r '.command')"
		echo -e "\`\`\`bash\n$COMMAND\n\`\`\`\n"
        local REPLY
        read -r -p "Approve execution? [y/N] " REPLY </dev/tty
		#read -p "Approve execution? [y/N] " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			echo "Command execution cancelled."
			exit 1
		fi

		eval "$COMMAND"
	else
		cat
	fi
}

# Dispatch (no outer conditional)
if [[ "$DEBUG" == true ]]; then
    respond "$@"
else
    respond "$@" | post_processors
fi
