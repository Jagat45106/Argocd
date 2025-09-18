#!/bin/bash
# Removed 'set -e' to handle errors manually and show debug logs
USERNAME="Jagat45106"
REQUIRED_TOPICS=("jfrog" "sonar" "ignore-all")

echo "Fetching repositories starting with 'Argo' for user: $USERNAME"

# Test GitHub CLI authentication first
echo "Testing GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated. Please run: gh auth login"
  exit 1
fi

echo "GitHub CLI is authenticated. Fetching repositories..."

# Get repositories with better error handling
all_repos=$(gh repo list "$USERNAME" --limit 50 --json name,repositoryTopics 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "Error: GitHub CLI command failed with exit code $exit_code"
  echo "Error output: $all_repos"
  echo "Please check if the username '$USERNAME' is correct"
  exit 1
fi

# Debug: Show raw output
echo "Raw GitHub CLI output:"
echo "$all_repos"
echo "---"

# Check if output is null or empty
if [ -z "$all_repos" ] || [ "$all_repos" = "null" ] || [ "$all_repos" = "[]" ]; then
  echo "No repositories found for user: $USERNAME"
  exit 1
fi

echo "Processing repositories with jq..."

# Use a simpler jq approach with better error handling
repos=$(echo "$all_repos" | jq -c '.[] | select(.name | startswith("Argo"))')

if [ -z "$repos" ]; then
  echo "No repositories found starting with 'Argo'"
  echo "Available repositories:"
  echo "$all_repos" | jq -r '.[].name'
  exit 0
fi

echo "Found Argo repositories:"
echo "$repos" | jq -r '.name'
echo ""

# Process each repository
echo "$repos" | while IFS= read -r repo_json; do
  repo_name=$(echo "$repo_json" | jq -r '.name')
  current_topics=($(echo "$repo_json" | jq -r '.repositoryTopics[]?.name // empty'))
  echo "Processing repository: $repo_name"
  echo "Current topics: ${current_topics[*]}"
  
  # Check for missing topics and add them
  missing_topics=()
  for required in "${REQUIRED_TOPICS[@]}"; do
    if ! printf '%s\n' "${current_topics[@]}" | grep -q "^${required}$"; then
      missing_topics+=("$required")
    fi
  done

  if [ ${#missing_topics[@]} -gt 0 ]; then
    echo "Missing topics for $repo_name: ${missing_topics[*]}"
    echo "Adding missing topics..."
    for topic in "${missing_topics[@]}"; do
      echo "  Adding topic: $topic"
      # Capture both stdout and stderr for debugging
      add_result=$(gh repo edit "$USERNAME/$repo_name" --add-topic "$topic" 2>&1)
      exit_code=$?
      
      if [ $exit_code -eq 0 ]; then
        echo "  ✓ Successfully added topic: $topic"
        if [ -n "$add_result" ]; then
          echo "  DEBUG: Command output: $add_result"
        fi
      else
        echo "  ✗ Failed to add topic: $topic"
        echo "  DEBUG: Exit code: $exit_code"
        echo "  DEBUG: Command: gh repo edit $USERNAME/$repo_name --add-topic $topic"
        echo "  DEBUG: Error output: $add_result"
      fi
    done
  else
    echo "All required topics are already present for $repo_name"
  fi
  echo ""
done

echo "Script finished"