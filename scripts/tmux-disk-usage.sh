#!/bin/sh
# Print "size used use%" for the root filesystem. `df -h /` is portable across
# Linux and macOS, and columns 2/3/5 are Size/Used/Use% on both. (The old
# `df --total` aggregate was GNU-only; root fs is the portable equivalent.)
df -h / | awk 'NR==2 {print $2, $3, $5}'
