
# Git Commit Helper Script

A PowerShell script to simplify common Git operations like committing changes, pushing to remote, branch management, and more.

## Features

- Interactive menu-driven interface
- Commit changes with categorized messages (feature, fix, docs, etc.)
- Automatic push to remote repository
- Branch management (create, switch, delete, merge)
- Pull updates from remote
- Multi-repository configuration support
- Recent commit history viewer
- Default branch configuration

## Requirements

- Windows PowerShell 5.1 or newer/PowerShell 7+
- Git installed and available in system PATH

## Installation

Save this script anywhere

## Usage

### First Run Setup
1. Open PowerShell
2. Navigate to script directory
3. Run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\commit-helper.ps1
```

### Main Menu Options
1. **Commit and push changes**  
   - Select commit type
   - Enter commit message
   - Automatic push to remote

2. **Manage branches**  
   - Create/delete branches
   - Switch between branches
   - Merge branches
   - Push/pull specific branches

3. **Pull from remote**  
   - Sync with remote repository

4. **View status and changes**  
   - See modified/added/deleted files
   - Check current branch status
   - View recent commit history

5. **Change repository**  
   - Switch between configured repositories
   - Add new repositories

### Configuration
- Automatically creates `git-helper-config.json` in script directory
- Stores:
  - Repository paths
  - Default branches
  - Lastest use

## Example Workflow

1. Select repository (need specify on the first run)
2. Choose "Commit and push changes"
3. Select commit type from list
4. Enter commit message
5. Review changes and confirm
6. Script automatically:
   - Stages all changes
   - Creates commit
   - Pushes to remote
   - Handles branch tracking

## Troubleshooting

### Common Issues
1. **Git not found**  
   Ensure Git is installed and available in PATH:
   ```powershell
   winget install --id Git.Git -e --source winget
   ```

2. **Execution Policy Restrictions**  
   Allow script execution:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Repository Detection Issues**  
   - Confirm directory contains `.git` folder
   - Run script from repository root

4. **Push/Pull Errors**  
   - Verify remote permissions
   - Check network connectivity
   - Ensure branch tracking is configured

## Best Practices

- Regularly pull changes before pushing
- Use meaningful commit messages
- Maintain clean branch history
- Configure upstream branches when pushing new branches
- Use the helper for routine operations - manual Git for complex scenarios

## License

[MIT License](LICENSE) - Free to use and modify with attribution

---

**Note:** Always review automatic changes before pushing to important repositories.