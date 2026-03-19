$ErrorActionPreference = "Stop"

try {
    $inputJson = [Console]::In.ReadToEnd()
    $data = $inputJson | ConvertFrom-Json

    $toolName = $data.toolName

    # Only inspect shell tool calls
    if ($toolName -ne "powershell" -and $toolName -ne "bash") {
        exit 0
    }

    # toolArgs is a JSON string — parse it to get the command
    $toolArgs = $data.toolArgs | ConvertFrom-Json
    $command = $toolArgs.command

    if (-not $command) {
        exit 0
    }

    # Only care about git commands
    if ($command -notmatch '(?i)\bgit\b') {
        exit 0
    }

    # Dangerous patterns to block
    $blockedPatterns = @(
        @{ Pattern = '(?i)\bgit\s+push\b.*\s(-f\b|--force\b)';          Reason = 'Force push (git push --force / -f) is blocked. It rewrites remote history and can permanently destroy others'' work.' },
        @{ Pattern = '(?i)\bgit\s+push\b.*--force-with-lease\b';        Reason = 'Force push with lease (--force-with-lease) is blocked. Even with a safety check, this rewrites remote history. Use a merge or rebase workflow instead.' },
        @{ Pattern = '(?i)\bgit\s+reset\b.*--hard\b';                   Reason = 'Hard reset (git reset --hard) is blocked. It permanently discards uncommitted changes and can lose work. Use --soft or --mixed, or stash changes first.' },
        @{ Pattern = '(?i)\bgit\s+clean\b.*-[a-zA-Z]*f[a-zA-Z]*';      Reason = 'git clean -f is blocked. It permanently deletes untracked files. Use "git clean -n" (dry run) to preview what would be removed.' },
        @{ Pattern = '(?i)\bgit\s+branch\b.*\s-D\b';                    Reason = 'Force branch delete (git branch -D) is blocked. Use -d (safe delete) which only deletes if the branch is fully merged.' },
        @{ Pattern = '(?i)\bgit\s+checkout\b.*\s(-f\b|--force\b)';      Reason = 'Forced checkout (git checkout --force / -f) is blocked. It silently discards local changes. Stash or commit first.' },
        @{ Pattern = '(?i)\bgit\s+stash\s+(drop|clear)\b';              Reason = 'git stash drop/clear is blocked. It permanently destroys stashed changes. Verify the stash contents first with "git stash show".' },
        @{ Pattern = '(?i)\bgit\s+rebase\b.*\s(-f\b|--force-rebase\b)'; Reason = 'Forced rebase (git rebase -f / --force-rebase) is blocked. It rewrites commit history unnecessarily.' }
    )

    foreach ($entry in $blockedPatterns) {
        if ($command -match $entry.Pattern) {
            $output = @{
                permissionDecision       = "deny"
                permissionDecisionReason = "[Git Safety Hook] $($entry.Reason)"
            }
            $output | ConvertTo-Json -Compress
            exit 0
        }
    }

    exit 0
}
catch {
    # On unexpected errors, fail open (don't block the tool)
    exit 0
}
