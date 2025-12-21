#!/bin/bash

GOAL="using create_function, create a function, list_functions, that runs 'ls'. call that function to make sure it worked. once done, call the 'finished' function. you can also call 'finished' if you have tried more than three times and the function is not working"

# Initialize the context array with the goal
declare -a CONTEXT_ARRAY=("$GOAL")
declare -a FUNCTIONS=("finished")
function get_functions() {
    # Build the function declarations dynamically
    for func_name in "${FUNCTIONS[@]}"; do
	declare -f "$func_name"
    done
}

function add_function() {
    function_name="$1"
    declare -f "$function_name" >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then
	echo "function $function_name not found" >&2
	return
    fi

    FUNCTIONS+=("$function_name")
}

function create_function() {
    echo "this is a meta function. you can use this function to create other functions which you can call down the line. this might be useful for things like automating test loops so you don't always have to run things manually" >/dev/null

    #set -x
    local function_name="$1"
    local function_code="$2"

    # Create the function in the current shell
    eval "$function_code"

    # Check if the function was successfully created
    if declare -f "$function_name" >/dev/null 2>&1; then
        export -f "$function_name" 2>/dev/null || true  # allow subshells to see the function
        # Add to FUNCTIONS array
	add_function "$function_name"
    else
        echo "Error: Failed to create function '$function_name'." >&2
        return 1
    fi
}

function get_context() {
    local full_context=""

    # Combine all elements of the context array
    for item in "${CONTEXT_ARRAY[@]}"; do
        full_context+="$item\n\n"
    done

    echo -e "$full_context"
}

function add_to_context() {
    local new_context="$1"
    CONTEXT_ARRAY+=("$new_context")
}

function setup_python_venv() {
    echo "you can use this function to set up python virtual environments. useful when you want to run a python script that has dependencies" >/dev/null
    local py_version="${1:-3.13}"  # Default to 3.13 if not provided
    shift || true  # Remove the version argument, if present

    # Create virtual environment with specified Python version
    rm -rf .venv
    uv venv --python "$py_version"
    source .venv/bin/activate

    # Install dependencies if provided
    if [ $# -gt 0 ]; then
        uv pip install "$@"
    fi
}

function write_code() {
    echo "you can use this function to write code in the language of your choice" >/dev/null
	goal="$1"
	language="$2"

	# figure out what extension we should use
	extension=$(llm "if you are writing code in $language, what extension should you use?" --schema "reasoning string, extension string: file extension including the leading '.'" | jq -r '.extension')

	file_name="code$extension"

	# write out code to current directory using appropriate extension
	llm "you are writing code to accomplish the following goal: $goal. use $language." --schema "reasoning string, code string: the code to generate. do not explain your work; if i copy your code paste it into a file and run it it should run immediately with no modications" | jq -r '.code' > "$file_name"

	# let the caller know contents of the code and where we wrote it
	echo "file_name=$file_name"
	echo
	echo "code=$(cat $file_name)"
}

function run_bash() {
    echo "you can use this function to run bash commands. this can be used for running code, examining the environment on which the code is running, etc" >/dev/null
	# run whatever command was passed in
	set -x
	eval "$@" 2>&1
	set +x
}

function finished() {
    echo "use this function when you want to exit" >/dev/null
	exit 0
}

function pick_function() {
        context="$(get_context)"

	PROMPT=$(cat <<EOF
Context:
$context

You can run the following bash functions:

$(get_functions)

Pick the function you want to run. Explain why.
EOF)
	echo "$PROMPT" | llm --schema "reasoning string, function_name string" | jq -r '.function_name'
}

function pick_command() {
        context="$(get_context)"
	function_name="$1"

	PROMPT=$(cat <<EOF
Context:
$context

You have chosen to run the following bash function:
$function_name

The code for this function is:
$(declare -f $function_name)

Invoke this function. Explain your reasoning
EOF)
	echo "$PROMPT" | llm --schema "reasoning string, command string" | jq -r '.command'
}

function main() {

    add_function create_function
    add_function setup_python_venv
    add_function write_code
    add_function run_bash

    #create_function "list_files" "list_files() { ls; }"
    #eval "list_files"
    #exit 0

    while true; do
        function_name="$(pick_function "$context")"
        echo "function choice: $function_name"

        if [ "$function_name" = "finished" ]; then
            echo "Agent has decided to exit."
            exit 0
        fi

        command="$(pick_command "$context" "$function_name")"
        echo "function call: $command"

	# run command in current shell, not a subshell
	# this allows for side effects
        tmp_out="$(mktemp)"
        { eval "$command"; } >"$tmp_out" 2>&1
        exit_code=$?
        result="$(<"$tmp_out")"
        rm -f "$tmp_out"

        #result="$(eval "$command")"
        #exit_code=$?

        echo "result of running function: $result"
        echo "(exit_code=$exit_code)"

        step_summary="Step:\nFunction: $function_name\nCommand: $command\nResult: $result\nExit Code: $exit_code"
        add_to_context "$step_summary"
    done
}

main
