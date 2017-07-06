# VSStoGIT

## What is it?
VSStoGit is a PowerShell script that can migrate (gasp) Microsoft SourceSafe repositories to Git. This aims to retain as much history as possible from the SourceSafe repository. At the top of the VSStoGit script there are set-up variables that will need to be modified in order to point the script to the correct SourceSafe and Git repositories. Once configured, hit run and enjoy!

### NOTE: This script was written in PowerShell 5.1. It is recommended that you install the latest version of PowerShell as the API is constantly changing. Tested on Windows 10 and Windows 7.

## How to Use
Simply open a PowerShell console window and type the following command:
```PowerShell
./VSStoGit.ps1 "GitProjectName" "Git repository URL" "Git branch name" "VSS repository name"
````
Note that GitObject.ps1 and HelperFunctions.ps1 need to be in the same directory that VSStoGit.ps1 is called in.

## How well has this been tested?
This program has not been extensively tested. It has successfully migrated the source code and project history from 10 VSS projects (under 500 MB of files), but that is only one dataset. 

### Known Issues
- Git.exe needs to be set as a path environment variable. 
- Sometimes the VSS command line utility refuses to get history/get latest versions for certain files, and when that happens this script simply skips right over that checkin. (You can thank Microsoft for that). 
- Email addresses for Git commits are formatted as "<name<name>>@email.com", where name is pulled from the corresponding VSS checkin. (Not really an issue, but worth noting). 
- .scc files are left over after migrating the project to Git. 
