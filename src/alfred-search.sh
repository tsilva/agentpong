#!/bin/bash
# Open Alfred with a keyword pre-filled
# Usage: alfred-search.sh <keyword>
osascript -e "tell application id \"com.runningwithcrayons.Alfred\" to search \"$1 \""
