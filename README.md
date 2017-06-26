# VSStoGIT

## What is it?
VSStoGit is a PowerShell script that can migrate (gasp) Microsoft SourceSafe repositories to Git. This aims to retain as much history as possible from the SourceSafe repository. At the top of the VSStoGit script there are set-up variables that will need to be modified in order to point the script to the correct SourceSafe and Git repositories. Once configured, hit run and enjoy!

### NOTE: This script was written in PowerShell 5.1. It is recommended that you install the latest version of PowerShell as the API is constantly changing. Tested on Windows 10 and Windows 7. (Has yet to be tested on Linux/MacOS).

### Known Issues
- Git.exe needs to be on the Windows search path (i.e. the PATH environment variable). 
- Sometimes the VSS command line utility refuses to get history/get latest versions for certain files, and when that happens this script simply skips right over that checkin.
- Email addresses for Git commits are in formatted as "<name<name>>@email.com", where name is pulled from the corresponding VSS checkin.
