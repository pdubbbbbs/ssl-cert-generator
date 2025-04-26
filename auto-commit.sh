#!/bin/bash

# Auto-commit and push script
# This script automatically commits and pushes changes every 15 minutes

while true; do
    cd "$(dirname "$0")"
    
    # Check if there are any changes
    if [[ -n $(git status -s) ]]; then
        echo "Changes detected. Committing and pushing..."
        
        # Add all changes
        git add .
        
        # Create commit with timestamp
        git commit -m "Auto-commit: $(date "+%Y-%m-%d %H:%M:%S")"
        
        # Push changes
        git push origin main
        
        echo "Changes pushed successfully."
    else
        echo "No changes detected at $(date "+%Y-%m-%d %H:%M:%S")"
    fi
    
    # Wait for 15 minutes
    sleep 900
done
