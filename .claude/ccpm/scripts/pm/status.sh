#!/bin/bash

echo "Getting status..."
echo ""
echo ""


echo "📊 Project Status"
echo "================"
echo ""

echo "📄 PRDs:"
if [ -d ".claude/prds" ]; then
  total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
  echo "  Total: $total"
else
  echo "  No PRDs found"
fi

echo ""
echo "📚 Epics:"
# Count epic directories, excluding .archived
if [ -d ".claude/epics" ]; then
  total=$(find .claude/epics -maxdepth 1 -mindepth 1 -type d ! -name ".archived" 2>/dev/null | wc -l)
  echo "  Total: $total"
else
  echo "  No epics found"
fi

echo ""
echo "📝 Tasks (from GitHub):"
# Use GitHub as source of truth for task status
if command -v gh &> /dev/null; then
  open=$(gh issue list --state open --label task --json number 2>/dev/null | grep -o '"number"' | wc -l)
  closed=$(gh issue list --state closed --label task --json number 2>/dev/null | grep -o '"number"' | wc -l)
  total=$((open + closed))
  echo "  Open: $open"
  echo "  Closed: $closed"
  echo "  Total: $total"
else
  echo "  GitHub CLI not available"
fi

exit 0
