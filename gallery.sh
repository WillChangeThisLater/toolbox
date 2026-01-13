#!/bin/bash

# Start HTML content
html_content='<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Gallery</title>
    <style>
        body { display: flex; flex-wrap: wrap; justify-content: center; }
        img { margin: 10px; border: 2px solid #ccc; border-radius: 5px; max-width: 300px; cursor: pointer; }
        img:hover { opacity: 0.7; }
    </style>
    <script>
        function copyToClipboard(url) {
            navigator.clipboard.writeText(url).then(() => {
                // do nothing
                ;
            });
        }
    </script>
</head>
<body>
'

# Read from standard input line by line
while IFS= read -r thumbnail; do
    if [ -f "$thumbnail" ]; then
        # If it's a file, convert to base64
        base64_content=$(base64 "$thumbnail")
        html_content+="<img src=\"data:image/png;base64,$base64_content\" alt=\"Thumbnail\" title=\"$thumbnail\" onclick=\"copyToClipboard('$thumbnail')\" />\n"
    else
        # Handle the case where it’s not a file (or you could choose to do something else)
        html_content+="<img src=\"$thumbnail\" alt=\"Thumbnail\" title=\"$thumbnail\" onclick=\"copyToClipboard('$thumbnail')\" />\n"
    fi
done

# Close the HTML content
html_content+='</body>
</html>
'

# Output the HTML to stdout
echo -e "$html_content"

