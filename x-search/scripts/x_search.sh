#!/bin/bash
# X Search via xAI Grok API
# Usage: x_search.sh "search query" [options]
# Options: --from-date YYYY-MM-DD --to-date YYYY-MM-DD --allowed-handles handle1,handle2 --excluded-handles handle1,handle2 --enable-images --enable-videos --thinking

set -euo pipefail

if [ -z "${XAI_API_KEY:-}" ]; then
    echo "Error: XAI_API_KEY environment variable not set" >&2
    exit 1
fi

API_HOST="${XAI_API_HOST:-https://api.x.ai}"
MODEL="grok-4-1-fast-non-reasoning"
QUERY=""
TOOL_CONFIG='{"type": "x_search"'
PARAMS_ADDED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --from-date)
            TOOL_CONFIG="${TOOL_CONFIG}, \"from_date\": \"$2\""
            PARAMS_ADDED=true
            shift 2
            ;;
        --to-date)
            TOOL_CONFIG="${TOOL_CONFIG}, \"to_date\": \"$2\""
            PARAMS_ADDED=true
            shift 2
            ;;
        --allowed-handles)
            HANDLES=$(echo "$2" | jq -R 'split(",") | map(. | @json) | join(", ")')
            TOOL_CONFIG="${TOOL_CONFIG}, \"allowed_x_handles\": [${HANDLES}]"
            PARAMS_ADDED=true
            shift 2
            ;;
        --excluded-handles)
            HANDLES=$(echo "$2" | jq -R 'split(",") | map(. | @json) | join(", ")')
            TOOL_CONFIG="${TOOL_CONFIG}, \"excluded_x_handles\": [${HANDLES}]"
            PARAMS_ADDED=true
            shift 2
            ;;
        --enable-images)
            TOOL_CONFIG="${TOOL_CONFIG}, \"enable_image_understanding\": true"
            PARAMS_ADDED=true
            shift
            ;;
        --enable-videos)
            TOOL_CONFIG="${TOOL_CONFIG}, \"enable_video_understanding\": true"
            PARAMS_ADDED=true
            shift
            ;;
        --thinking)
            MODEL="grok-4-1-fast-reasoning"
            shift
            ;;
        *)
            QUERY="$1"
            shift
            ;;
    esac
done

TOOL_CONFIG="${TOOL_CONFIG}}"

if [ -z "$QUERY" ]; then
    echo "Error: Search query required" >&2
    exit 1
fi

PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "input": [
    {
      "role": "user",
      "content": "$QUERY"
    }
  ],
  "tools": [
    $TOOL_CONFIG
  ]
}
EOF
)

RESPONSE=$(curl -s "${API_HOST}/v1/responses" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${XAI_API_KEY}" \
  -d "$PAYLOAD")

# Parse and display the response
echo "$RESPONSE" | jq -r '
  .output[-1].content[0] as $content |

  # Extract text
  ($content.text // "No response text found" | gsub("~"; "\\~")) as $text |

  # Extract unique citations and sort by title
  ($content.annotations // [] | map(select(.type == "url_citation")) |
   unique_by(.url) | sort_by(.title | tonumber) | map("[\(.title)] \(.url)") | join("\n")) as $citations |

  # Format output
  "## Response\n\n" + $text +
  (if $citations != "" then "\n\n## Citations\n" + $citations else "" end)
'
