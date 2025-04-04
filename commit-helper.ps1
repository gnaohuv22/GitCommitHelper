# Auto Git Commit and Push Script v2
# -----------------------------------------------------------
# This script helps commit and push changes to Git repositories interactively
# Usage: .\git-push-helper.ps1

# Configuration file to store information
$configFile = Join-Path $PSScriptRoot "git-helper-config.json"

# Check if Git is installed
function Test-GitInstalled {
    try {
        git --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Check if directory is a valid Git repository
function Test-ValidGitRepository {
    param ([string]$path)
    
    if (-not (Test-Path -Path (Join-Path $path ".git"))) {
        return $false
    }
    
    try {
        Push-Location $path
        $gitStatus = git status 2>&1
        Pop-Location
        
        # If git status succeeds, it's a valid git repository
        return $true
    } catch {
        Pop-Location
        return $false
    }
}

# Check repository status
function Test-GitStatus {
    param ([string]$path)
    
    Set-Location $path
    $status = git status --porcelain
    return $status.Length -gt 0
}

# Display list of changes
function Show-GitChanges {
    param ([string]$path)
    
    Set-Location $path
    Write-Host "`nYour changes:" -ForegroundColor Cyan
    
    $status = git status --porcelain
    
    if ($status.Length -eq 0) {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        return $false
    }
    
    $modified = $status | Where-Object { $_ -match '^ M|^M ' }
    $added = $status | Where-Object { $_ -match '^\?\?' }
    $deleted = $status | Where-Object { $_ -match '^ D|^D ' }
    
    if ($modified.Count -gt 0) {
        Write-Host "`nModified files:" -ForegroundColor Yellow
        $modified | ForEach-Object { Write-Host "  $($_ -replace '^ M|^M ', '')" }
    }
    
    if ($added.Count -gt 0) {
        Write-Host "`nNew files:" -ForegroundColor Green
        $added | ForEach-Object { Write-Host "  $($_ -replace '^\?\? ', '')" }
    }
    
    if ($deleted.Count -gt 0) {
        Write-Host "`nDeleted files:" -ForegroundColor Red
        $deleted | ForEach-Object { Write-Host "  $($_ -replace '^ D|^D ', '')" }
    }
    
    return $true
}

# Read saved configuration
function Get-SavedConfig {
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            return $config
        } catch {
            return $null
        }
    }
    return $null
}

# Save configuration with multiple repositories
function Save-Config {
    param (
        [string]$repoPath,
        [string]$defaultBranch,
        [bool]$makeDefault = $false
    )
    
    $config = Get-SavedConfig
    
    if ($null -eq $config) {
        $config = @{
            Repositories = @()
            DefaultRepo = $repoPath
            LastUsed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Check if repository already exists in config
    $repoExists = $false
    foreach ($repo in $config.Repositories) {
        if ($repo.Path -eq $repoPath) {
            $repo.DefaultBranch = $defaultBranch
            $repo.LastUsed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $repoExists = $true
            break
        }
    }
    
    # Add new repository if it doesn't exist
    if (-not $repoExists) {
        $newRepo = @{
            Path = $repoPath
            DefaultBranch = $defaultBranch
            LastUsed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $config.Repositories += $newRepo
    }
    
    # Update default repository if requested
    if ($makeDefault) {
        $config.DefaultRepo = $repoPath
    }
    
    $config.LastUsed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Save configuration
    $config | ConvertTo-Json -Depth 4 | Set-Content $configFile
}

# Display recent commits
function Show-RecentCommits {
    param ([int]$count = 5)
    
    Write-Host "`nRecent commits:" -ForegroundColor Cyan
    git log -n $count --pretty=format:"%h %s" | ForEach-Object {
        Write-Host "  $_"
    }
    Write-Host ""
}

# Check which branches are being tracked from remote
function Get-TrackingBranches {
    $branches = git branch -vv
    $trackingInfo = @{}
    
    foreach ($branch in $branches) {
        if ($branch -match '^\*?\s+(\S+).*\[(\S+)\/(\S+).*\]') {
            $localBranch = $matches[1]
            $remote = $matches[2]
            $remoteBranch = $matches[3]
            $trackingInfo[$localBranch] = @{
                Remote = $remote
                Branch = $remoteBranch
            }
        }
    }
    
    return $trackingInfo
}

# Branch management function
function Manage-GitBranches {
    param ([string]$repoPath)
    
    Set-Location $repoPath
    Clear-Host
    
    while ($true) {
        Write-Host "=== Branch Management ===" -ForegroundColor Cyan
        
        # Get current branch
        $currentBranch = git rev-parse --abbrev-ref HEAD
        Write-Host "`nCurrent branch: $currentBranch" -ForegroundColor Yellow
        
        # Get all local branches
        $branches = git branch --format="%(refname:short)"
        $branchList = $branches -split "`n"
        
        # Get remote branches
        $remoteBranches = git branch -r --format="%(refname:short)"
        $remoteBranchList = $remoteBranches -split "`n" | ForEach-Object { $_.Replace("origin/", "") } | Where-Object { $_ -notmatch "HEAD" }
        
        Write-Host "`nLocal branches:" -ForegroundColor Yellow
        for ($i=0; $i -lt $branchList.Count; $i++) {
            $prefix = if ($branchList[$i] -eq $currentBranch) { "* " } else { "  " }
            Write-Host "$prefix$($i+1). $($branchList[$i])"
        }
        
        Write-Host "`nBranch operations:" -ForegroundColor Cyan
        Write-Host "  1. Create new branch"
        Write-Host "  2. Switch to another branch"
        Write-Host "  3. Delete a branch"
        Write-Host "  4. Merge branches"
        Write-Host "  5. Pull from remote"
        Write-Host "  6. Push to remote"
        Write-Host "  7. Return to main menu"
        
        $choice = Read-Host "`nSelect operation (1-7)"
        
        switch ($choice) {
            "1" { # Create new branch
                $newBranchName = Read-Host "`nEnter new branch name"
                
                if ($newBranchName -ne "") {
                    Write-Host "Creating branch '$newBranchName'..." -ForegroundColor Yellow
                    
                    try {
                        git checkout -b $newBranchName
                        Write-Host "Branch created successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error creating branch: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            
            "2" { # Switch to another branch
                $switchInput = Read-Host "`nEnter branch number or name"
                
                if ($switchInput -match '^\d+$' -and [int]$switchInput -le $branchList.Count -and [int]$switchInput -gt 0) {
                    $branchToSwitch = $branchList[[int]$switchInput-1]
                } else {
                    $branchToSwitch = $switchInput
                }
                
                if ($branchToSwitch -ne "" -and $branchToSwitch -ne $currentBranch) {
                    Write-Host "Switching to branch '$branchToSwitch'..." -ForegroundColor Yellow
                    
                    try {
                        git checkout $branchToSwitch
                        Write-Host "Switched successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error switching branch: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            
            "3" { # Delete a branch
                $deleteInput = Read-Host "`nEnter branch number or name to delete"
                
                if ($deleteInput -match '^\d+$' -and [int]$deleteInput -le $branchList.Count -and [int]$deleteInput -gt 0) {
                    $branchToDelete = $branchList[[int]$deleteInput-1]
                } else {
                    $branchToDelete = $deleteInput
                }
                
                if ($branchToDelete -ne "" -and $branchToDelete -ne $currentBranch) {
                    $force = Read-Host "Force delete? (y/N)"
                    $forceFlag = if ($force.ToLower() -eq "y") { "-D" } else { "-d" }
                    
                    Write-Host "Deleting branch '$branchToDelete'..." -ForegroundColor Yellow
                    
                    try {
                        git branch $forceFlag $branchToDelete
                        Write-Host "Branch deleted successfully!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error deleting branch: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } elseif ($branchToDelete -eq $currentBranch) {
                    Write-Host "Cannot delete the current branch. Switch to another branch first." -ForegroundColor Red
                }
            }
            
            "4" { # Merge branches
                $mergeFrom = Read-Host "`nEnter branch number or name to merge from"
                
                if ($mergeFrom -match '^\d+$' -and [int]$mergeFrom -le $branchList.Count -and [int]$mergeFrom -gt 0) {
                    $branchToMerge = $branchList[[int]$mergeFrom-1]
                } else {
                    $branchToMerge = $mergeFrom
                }
                
                if ($branchToMerge -ne "" -and $branchToMerge -ne $currentBranch) {
                    Write-Host "Merging branch '$branchToMerge' into '$currentBranch'..." -ForegroundColor Yellow
                    
                    try {
                        git merge $branchToMerge
                        Write-Host "Merge completed!" -ForegroundColor Green
                    } catch {
                        Write-Host "Error during merge: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } elseif ($branchToMerge -eq $currentBranch) {
                    Write-Host "Cannot merge a branch with itself." -ForegroundColor Red
                }
            }
            
            "5" { # Pull from remote
                $remote = Read-Host "`nEnter remote name (default: origin)"
                if ($remote -eq "") { $remote = "origin" }
                
                Write-Host "Pulling from remote '$remote'..." -ForegroundColor Yellow
                
                try {
                    git pull $remote $currentBranch
                    Write-Host "Pull completed!" -ForegroundColor Green
                } catch {
                    Write-Host "Error during pull: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            "6" { # Push to remote
                $remote = Read-Host "`nEnter remote name (default: origin)"
                if ($remote -eq "") { $remote = "origin" }
                
                $setUpstream = Read-Host "Set as upstream? (y/N)"
                $upstreamFlag = if ($setUpstream.ToLower() -eq "y") { "-u" } else { "" }
                
                Write-Host "Pushing to remote '$remote'..." -ForegroundColor Yellow
                
                try {
                    if ($upstreamFlag -ne "") {
                        git push $upstreamFlag $remote $currentBranch
                    } else {
                        git push $remote $currentBranch
                    }
                    Write-Host "Push completed!" -ForegroundColor Green
                } catch {
                    Write-Host "Error during push: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            "7" { # Return to main menu
                return
            }
            
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
            }
        }
        
        Write-Host "`nPress any key to continue..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
    }
}

# Select repository function
function Select-GitRepository {
    $config = Get-SavedConfig
    $repoPath = ""
    $defaultBranch = ""
    
    if ($null -eq $config -or $null -eq $config.Repositories -or $config.Repositories.Count -eq 0) {
        # No saved repositories, get a new one
        return Add-NewRepository
    }
    
    Clear-Host
    Write-Host "=== Repository Selection ===" -ForegroundColor Cyan
    Write-Host "`nSaved repositories:" -ForegroundColor Yellow
    
    $repoOptions = @()
    for ($i=0; $i -lt $config.Repositories.Count; $i++) {
        $repo = $config.Repositories[$i]
        $isDefault = if ($repo.Path -eq $config.DefaultRepo) { " (default)" } else { "" }
        Write-Host "  $($i+1). $($repo.Path)$isDefault"
        $repoOptions += $repo.Path
    }
    
    Write-Host "`n  N. Add new repository"
    Write-Host "  Q. Quit"
    
    $repoChoice = Read-Host "`nSelect repository or option"
    
    if ($repoChoice.ToLower() -eq "q") {
        exit 0
    } elseif ($repoChoice.ToLower() -eq "n") {
        # User wants to add a new repository
        return Add-NewRepository
    } elseif ($repoChoice -match '^\d+$' -and [int]$repoChoice -le $repoOptions.Count -and [int]$repoChoice -gt 0) {
        # User selected an existing repository
        $selectedRepo = $config.Repositories[[int]$repoChoice-1]
        $repoInfo = @{
            Path = $selectedRepo.Path
            DefaultBranch = $selectedRepo.DefaultBranch
        }
        return $repoInfo
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return Select-GitRepository  # Recursively try again
    }
}

# Add new repository function
function Add-NewRepository {
    Clear-Host
    Write-Host "=== Add New Repository ===" -ForegroundColor Cyan
    
    # Get repository path
    $repoPath = Read-Host "`nEnter the path to Git repository (Press Enter to use current directory)"
    
    if ($repoPath -eq "") {
        $repoPath = Get-Location
    } elseif (-not (Test-Path $repoPath)) {
        Write-Host "Path does not exist. Please check again." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return Add-NewRepository  # Try again
    }
    
    # Check if it's a Git repository
    $isGitRepo = Test-ValidGitRepository -path $repoPath
    
    # If it's not a Git repository, suggest git init
    if (-not $isGitRepo) {
        Write-Host "The specified directory is not a Git repository: $repoPath" -ForegroundColor Yellow
        $initConfirm = Read-Host "Do you want to initialize a Git repository here? (Y/n)"
        
        if ($initConfirm -eq "" -or $initConfirm.ToLower() -eq "y") {
            Set-Location $repoPath
            
            # Initialize Git repository
            Write-Host "Initializing Git repository..." -ForegroundColor Yellow
            git init
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error initializing Git repository." -ForegroundColor Red
                Read-Host "Press Enter to continue"
                return Add-NewRepository  # Try again
            }
            
            # Set default branch name
            $branchName = Read-Host "`nEnter default branch name (default: main)"
            if ($branchName -eq "") { $branchName = "main" }
            
            # Check if there's already a commit to rename the branch
            $hasCommits = git log -n 1 2>$null
            
            if ($hasCommits) {
                # Rename current branch if there are commits
                git branch -M $branchName
            } else {
                # Store branch name for future use
                $env:GIT_FIRST_BRANCH = $branchName
            }
            
            # Add remote repository URL
            $remoteUrl = Read-Host "`nEnter remote repository URL (leave empty to skip)"
            if ($remoteUrl -ne "") {
                git remote add origin $remoteUrl
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Error adding remote repository." -ForegroundColor Red
                }
            }
            
            Write-Host "Git repository initialized successfully!" -ForegroundColor Green
            $isGitRepo = $true
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Read-Host "Press Enter to continue"
            return Add-NewRepository  # Try again
        }
    }
    
    # Go to repository
    Set-Location $repoPath
    
    # Get all local branches
    $branches = git branch --format="%(refname:short)" 2>$null
    $branchList = @()
    
    if ($branches) {
        $branchList = $branches -split "`n"
    }
    
    # Get current branch or handle new repository case
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    
    # If this is a brand new repository with no commits, check if we saved a branch name
    if (-not $currentBranch -or $currentBranch -eq "HEAD") {
        if ($env:GIT_FIRST_BRANCH) {
            $currentBranch = $env:GIT_FIRST_BRANCH
        } else {
            $currentBranch = "main"  # Default to main for new repositories
        }
    }
    
    if ($branchList.Count -gt 0) {
        Write-Host "`nAvailable branches:" -ForegroundColor Yellow
        for ($i=0; $i -lt $branchList.Count; $i++) {
            $prefix = if ($branchList[$i] -eq $currentBranch) { "* " } else { "  " }
            Write-Host "$prefix$($i+1). $($branchList[$i])"
        }
        
        # Ask which branch to use as default
        $branchInput = Read-Host "`nSelect default branch (Press Enter to use current branch '$currentBranch')"
        
        if ($branchInput -eq "") {
            $defaultBranch = $currentBranch
        } elseif ($branchInput -match '^\d+$' -and [int]$branchInput -le $branchList.Count -and [int]$branchInput -gt 0) {
            $defaultBranch = $branchList[[int]$branchInput-1]
        } else {
            $defaultBranch = $branchInput
        }
    } else {
        # No branches yet, use the branch name we determined earlier
        $defaultBranch = $currentBranch
        Write-Host "`nUsing '$defaultBranch' as the default branch." -ForegroundColor Yellow
    }
    
    # Make this repository default?
    $makeDefault = $true
    $config = Get-SavedConfig
    if ($null -ne $config -and $null -ne $config.Repositories -and $config.Repositories.Count -gt 0) {
        $makeDefaultInput = Read-Host "`nMake this the default repository? (Y/n)"
        $makeDefault = $makeDefaultInput -eq "" -or $makeDefaultInput.ToLower() -eq "y"
    }
    
    # Save configuration
    Save-Config -repoPath $repoPath -defaultBranch $defaultBranch -makeDefault $makeDefault
    
    # Return repository info
    $repoInfo = @{
        Path = $repoPath
        DefaultBranch = $defaultBranch
    }
    return $repoInfo
}

# Main function
function Start-GitHelper {
    # Check if Git is installed
    if (-not (Test-GitInstalled)) {
        Write-Host "Git is not installed or not in PATH. Please install Git and try again." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    # Check Git configuration
    if (-not (Test-GitConfig)) {
        Fix-GitConfig
    }
    
    # First time repository selection
    $repoInfo = Select-GitRepository
    $currentRepoPath = $repoInfo.Path
    $currentDefaultBranch = $repoInfo.DefaultBranch
    
    # Main menu loop
    while ($true) {
        Clear-Host
        Write-Host "=== Git Commit and Push Helper v2 ===" -ForegroundColor Cyan
        Write-Host "`nCurrent repository: $currentRepoPath" -ForegroundColor Yellow
        Write-Host "Default branch: $currentDefaultBranch" -ForegroundColor Yellow
        
        # Show repository operations menu
        Write-Host "`nSelect operation:" -ForegroundColor Yellow
        Write-Host "  1. Commit and push changes"
        Write-Host "  2. Manage branches"
        Write-Host "  3. Pull from remote"
        Write-Host "  4. View status and changes"
        Write-Host "  5. Change repository"
        Write-Host "  6. Quit"
        
        $operationChoice = Read-Host "`nSelect operation (1-6)"
        
        switch ($operationChoice) {
            "1" { # Commit and push changes
                Clear-Host
                Write-Host "=== Commit and Push Changes ===" -ForegroundColor Cyan
                
                # Go to repository
                Set-Location $currentRepoPath
                
                # Display tracking information
                $trackingInfo = Get-TrackingBranches
                
                # Display changes
                $hasChanges = Show-GitChanges -path $currentRepoPath
                
                if (-not $hasChanges) {
                    Write-Host "`nNo changes to commit." -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                    continue
                }
                
                # Get current branch
                $currentBranch = git rev-parse --abbrev-ref HEAD
                
                # Display recent commits
                Show-RecentCommits
                
                # Ask for commit type
                Write-Host "`nSelect commit type:" -ForegroundColor Yellow
                Write-Host "  1. feature: New feature"
                Write-Host "  2. fix: Bug fix"
                Write-Host "  3. docs: Documentation update"
                Write-Host "  4. refactor: Code refactoring"
                Write-Host "  5. style: Formatting, missing semicolons,..."
                Write-Host "  6. test: Adding or fixing tests"
                Write-Host "  7. chore: Maintenance tasks"
                
                $commitTypeInput = Read-Host "`nSelect commit type (1-7, default: 7)"
                
                $commitTypes = @("feature", "fix", "docs", "refactor", "style", "test", "chore")
                $commitTypeIndex = 6  # Default is "chore"
                
                if ($commitTypeInput -match '^\d+$' -and [int]$commitTypeInput -le 7 -and [int]$commitTypeInput -gt 0) {
                    $commitTypeIndex = [int]$commitTypeInput - 1
                }
                
                $commitType = $commitTypes[$commitTypeIndex]
                
                # Ask for commit message
                $commitMessage = Read-Host "`nEnter description for commit (leave empty to use default message)"
                
                if ($commitMessage -eq "") {
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $commitMessage = "Automatic update at $timestamp"
                }
                
                $fullCommitMessage = "[$commitType] $commitMessage"
                
                # Confirm information
                Write-Host "`nCommit information:" -ForegroundColor Cyan
                Write-Host "  Repository: $currentRepoPath"
                Write-Host "  Current branch: $currentBranch"
                Write-Host "  Commit message: $fullCommitMessage"
                
                $confirm = Read-Host "`nDo you want to continue? (Y/n)"
                
                if ($confirm -ne "" -and $confirm.ToLower() -ne "y") {
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                    Read-Host "Press Enter to continue"
                    continue
                }
                
                # Execute Git operations with error handling
                try {
                    # Switch branch if needed
                    if ($currentBranch -ne $currentDefaultBranch) {
                        $switchBranch = Read-Host "`nYou are on branch '$currentBranch', not the default branch '$currentDefaultBranch'. Do you want to switch branch? (y/N)"
                        
                        if ($switchBranch.ToLower() -eq "y") {
                            Write-Host "Switching from branch '$currentBranch' to '$currentDefaultBranch'..." -ForegroundColor Yellow
                            git checkout $currentDefaultBranch
                            
                            if ($LASTEXITCODE -ne 0) {
                                throw "Cannot switch to branch $currentDefaultBranch. Branch does not exist or there is another error."
                            }
                            
                            $currentBranch = $currentDefaultBranch
                        }
                    }
                    
                    # Stage all changes
                    Write-Host "`nAdding all changes..." -ForegroundColor Yellow
                    git add .
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "Error adding changes to staging area."
                    }
                    
                    # Commit changes
                    Write-Host "Committing with message: $fullCommitMessage" -ForegroundColor Yellow
                    git commit -m $fullCommitMessage
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "Error committing changes."
                    }
                    
                    # Check if branch is being tracked
                    $needsUpstream = $false
                    if ($currentBranch -in $trackingInfo.Keys) {
                        $remoteBranch = "$($trackingInfo[$currentBranch].Remote)/$($trackingInfo[$currentBranch].Branch)"
                        Write-Host "Pushing to '$remoteBranch'..." -ForegroundColor Yellow
                        git push
                    } else {
                        $needsUpstream = $true
                        $remoteOption = Read-Host "`nBranch '$currentBranch' has no upstream. Which remote do you want to push to? (default: origin)"
                        
                        $remote = if ($remoteOption -eq "") { "origin" } else { $remoteOption }
                        
                        # Check if remote exists, if not, ask for URL
                        $remoteExists = git remote get-url $remote 2>$null
                        
                        if (-not $remoteExists) {
                            Write-Host "Remote '$remote' does not exist." -ForegroundColor Yellow
                            $remoteUrl = Read-Host "Enter remote URL for '$remote'"
                            
                            if ($remoteUrl -ne "") {
                                git remote add $remote $remoteUrl
                                
                                if ($LASTEXITCODE -ne 0) {
                                    throw "Error adding remote '$remote'."
                                }
                                
                                Write-Host "Remote '$remote' added successfully." -ForegroundColor Green
                            } else {
                                throw "Cannot push without a valid remote."
                            }
                        }
                        
                        Write-Host "Pushing and setting upstream for branch '$currentBranch' to '$remote/$currentBranch'..." -ForegroundColor Yellow
                        git push -u $remote $currentBranch
                    }
                    
                    if ($LASTEXITCODE -ne 0) {
                        if ($needsUpstream) {
                            throw "Error pushing to branch $currentBranch. Remote branch does not exist or you don't have permission to push."
                        } else {
                            throw "Error pushing to branch $currentBranch."
                        }
                    }
                    
                    Write-Host "`nSuccessfully committed and pushed changes!" -ForegroundColor Green
                    
                } catch {
                    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                Read-Host "Press Enter to continue"
            }
            
            "2" { # Branch management
                Manage-GitBranches -repoPath $currentRepoPath
            }
            
            "3" { # Pull from remote
                Clear-Host
                Write-Host "=== Pull from Remote ===" -ForegroundColor Cyan
                
                # Go to repository
                Set-Location $currentRepoPath
                
                $remote = Read-Host "`nEnter remote name (default: origin)"
                if ($remote -eq "") { $remote = "origin" }
                
                $branch = Read-Host "Enter branch name (default: current branch)"
                if ($branch -eq "") { $branch = git rev-parse --abbrev-ref HEAD }
                
                Write-Host "`nPulling from '$remote/$branch'..." -ForegroundColor Yellow
                
                try {
                    git pull $remote $branch
                    Write-Host "Pull completed successfully!" -ForegroundColor Green
                } catch {
                    Write-Host "Error during pull: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                Read-Host "Press Enter to continue"
            }
            
            "4" { # View status and changes
                Clear-Host
                Write-Host "=== Repository Status ===" -ForegroundColor Cyan
                
                # Go to repository
                Set-Location $currentRepoPath
                
                # Display current branch
                $currentBranch = git rev-parse --abbrev-ref HEAD
                Write-Host "`nCurrent branch: $currentBranch" -ForegroundColor Yellow
                
                # Display changes
                Show-GitChanges -path $currentRepoPath
                
                # Display recent commits
                Show-RecentCommits -count 10
                
                Read-Host "Press Enter to continue"
            }
            
            "5" { # Change repository
                $repoInfo = Select-GitRepository
                $currentRepoPath = $repoInfo.Path
                $currentDefaultBranch = $repoInfo.DefaultBranch
            }
            
            "6" { # Quit
                Write-Host "Goodbye!" -ForegroundColor Cyan
                exit 0
            }
            
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Check Git configuration
function Test-GitConfig {
    try {
        $userEmail = git config --global user.email
        $userName = git config --global user.name
        
        return ($userEmail -ne $null -and $userEmail -ne "") -and ($userName -ne $null -and $userName -ne "")
    } catch {
        return $false
    }
}

# Fix Git configuration
function Fix-GitConfig {
    Write-Host "`nGit configuration is incomplete. Setting up your Git identity." -ForegroundColor Yellow
    
    $userName = Read-Host "Enter your name for Git commits"
    $userEmail = Read-Host "Enter your email for Git commits"
    
    if ($userName -and $userEmail) {
        git config --global user.name $userName
        git config --global user.email $userEmail
        
        Write-Host "Git configuration updated successfully." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Cannot continue without Git identity configuration." -ForegroundColor Red
        return $false
    }
}

# Run main function
Start-GitHelper
# Terminal will not exit automatically after completion because of the menu loop