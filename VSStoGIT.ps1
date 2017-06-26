try{
. C:/Users/MolinaBA/Desktop/VSStoGIT/GitObject.ps1
. C:/Users/MolinaBA/Desktop/VSStoGIT/HelperFunctions.ps1
}
catch{
  Write-Host "Error while importing GitObject/HelperFunctions .ps1. Check paths.
}

#----------------------------------------------------------------------------------------
#                              Script Set-up Variables
#----------------------------------------------------------------------------------------
# Tell script where to place working folder
$workingFolder = New-Item "C:/Users/MolinaBA/Desktop/VSStoGit" -ItemType directory -force
# Tell script what Git repository to push data to
$gitRepositoryURL = "https://MolinaBA@USTR-GITLAB-1.na.uis.unisys.com/MCPTest/WinMQ-GitMigration-Test.git"
# Tell script what Git branch to push data to
$gitBranchName = "00"
# Tell script the name of the Git project (the one that was cloned)
$gitFolderName = "WinMQ-GitMigration-Test"
# Tell script what VSS repository to pull data from
$VSS_ServerName = "`"$\00\WinMQ`""
# Tell script the location of Git Bash (usually in C:\Program Files)
$gitBashPath = "C:\Program Files\Git\bin\sh.exe"
#----------------------------------------------------------------------------------------

# Clone empty Git repository and get VSS history
cd $workingFolder
git config --global http.sslVerify false
git clone -b $gitBranchName $gitRepositoryURL
$VSSHistory = ss History $VSS_ServerName -R # Grab VSS history


#----------------------------------------------------------------------------------------
#                             Create Unique VSS Checkin Log
# Purpose: This section constructs a list of Git Tag and Git Commit objects. It does
# this by iterating through $UniqueVSSCheckinLog (which is a text file containing
# unique SourceSafe checkins by date and time), and determining if the checkin is
# a file checkin or a label checkin (or both perhaps).
#
#   INPUT:
#     - VSSHistory : A text file (probably very large) that contains every single
#     VSS checkin.
#
#   OUTPUT:
#     - UniqueVSSCheckinLog : A text file (much smaller) that contains only unique
#     VSS file and label checkins by date and time
#----------------------------------------------------------------------------------------
$HistoryFileName = "VSSHistory.txt"
New-Item "$workingFolder/$HistoryFileName" -type file
New-Item "temp.txt" -type file
add-content -path "$workingFolder/$HistoryFileName" -value $VSSHistory
get-content $HistoryFileName | select -Skip 3 | set-content "temp.txt" # Remove unnecessary 'Building list...' part of VSS History log
move "temp.txt" $HistoryFileName -force

# Create a new text file that only contains unique VSS checkin dates/times
$UniqueVSSCheckinLog = "VSSCheckinLog-Unique.txt"
New-Item "$workingFolder/$UniqueVSSCheckinLog" -type file

# Get VSS checkins with dates that are greater to or equal than 2004
$content = get-content "$workingFolder/$HistoryFileName" | select-string -Pattern  "Date:(.*)/(.*)/(([0][4-9])|([1][0-9]))(.*)"

# Reverse date/time content (Git commands will be performed starting from 2004-Present)
[array]::Reverse($content)

# Extract dates/times
$content = $content -replace "User:", " "
$content = $content -replace "Date:", " "
$content = $content -replace "Time:", " "
$content = $content.Trim()
$date = $content -Replace '^.[a-z]*', ''
$date = $date -Replace '^[^\s]*', ''
$date = $date.Trim()
$time = $date -Replace '^([^\s]+)\s', ''
$time = $time.Trim()
$date = $date -Replace '\s(.*)', ''
$date = $date.Trim()
$newDate = $date -replace '/','-'


## Fill the unique dates/times text file with unique VSS Checkins. A unique VSS checkin will allow this script to
## get the source/label files from VSS that were checked in with the timestamp
$dateArrayLength = $date.Length
for($index = 0; $index -lt $dateArrayLength; $index++) {
    $Different_Time = !($time[$index] -match $time[($index+1)]) -or !($time[($index+1)])
    $Same_Time_Diff_Date = ($time[$index] -match $time[($index+1)]) -and !($date[$index] -match $date[($index+1)])
    if($Different_Time -or $Same_Time_Diff_Date){
      $lowerBound = SubtractByOneMin $newDate[$index] $time[$index]
      $lowerBound = $lowerBound -split ' '
      $uniqueDate  = "ss Get $VSS_ServerName -R -Vd$($newDate[$index])"";""$($time[$index])~$($lowerBound[0])"";""$($lowerBound[1]) -I-N" # Creates SourceSafe command to get file by dates & time
      add-content "$workingFolder/$UniqueVSSCheckinLog" $uniqueDate -force
    }
}

#----------------------------------------------------------------------------------------
#                             Create Unique VSS Checkin Log
# Purpose: This section constructs a list of Git Tag and Git Commit objects. It does
# this by iterating through UniqueVSSCheckinLog (which is a text file containing
# unique SourceSafe checkins by date and time), and determining if the checkin is
# a file checkin or a label checkin.
#
#   INPUT:
#     - UniqueVSSCheckinLog : A text file containing unique VSS checkin date/times
#
#   OUTPUT:
#     - gitObjectList : A list of Git Tag and Git Commit objects
#----------------------------------------------------------------------------------------
# Create empty list to store Git Commit and Git Tag objects
$gitObjectList = New-Object System.Collections.ArrayList

ForEach($checkinCommand in Get-Content $workingFolder/$UniqueVSSCheckinLog){

    # prepare vss history command
    $checkinCommand = $checkinCommand -Replace 'Get','History'
    # run the vss history command and store the output
    $checkin = invoke-expression $checkinCommand | select -Skip 3
    # Handles when the stupid SourceSafe command line utility doesnt work (i.e. error "Version not found")
    if($checkin -eq $Null){
      Continue
    }
    # Create a Git commit and Git tag when a VSS checkin contains both label and file(s) checkin on same date
    elseif($checkin -match "Checked in" -and $checkin -match "Label:"){
        $newGitCommit = CreateGitCommit $checkinCommand
        $newGitTag    = CreateGitTag $checkinCommand
        $gitObjectList.Add($newGitCommit) > $null
        $gitObjectList.Add($newGitTag) > $null
    }
    # Create a Git tag if the VSS checkin contains only a label
    elseif($checkin -match "Label:"){
        $newGitTag = CreateGitTag $checkinCommand
        $gitObjectList.Add($newGitTag) > $null
    }
    # Else create a Git commit if the VSS checkin contains only file(s) checkins
    else{
        $newGitCommit = CreateGitCommit $checkinCommand
        $gitObjectList.Add($newGitCommit) > $null
    }

}

#----------------------------------------------------------------------------------------
#                             Create Unique VSS Checkin Log
# Purpose: This section iterates through gitObjectList (an ArrayList of Git Tags
# and Git Commits) and executes Git commands based on the object type.
#
#   INPUT:
#     - gitObjectList : An ArrayList of Git Tag and Git Commit objects
#
#   OUTPUT:
#     - OverallLog.txt : A text file containing all of the Git commands that were
#       executed from the migration process. (Can be used for debugging purposes)
#
#     - A filled Git repository : If every Git command succeeds, the target Git
#     repository should be filled with every VSS file and its corresponding history.
#----------------------------------------------------------------------------------------
New-Item "GitCommands.sh" -type file  # Create Git command file that will be executed
New-Item "OverallLog.txt" -type file  # Create log file which will contain every git commit/git tag command that is executed
$commitCounter = 1 # For displaying commit number on top of each commit in OverallLog.txt

# Loop through gitObjectList and add each git commit/tag (in order) to the cloned git repository
ForEach($currentObject in $gitObjectList){

    # If the current object is a Git Commit object, then call Git Add, Commit, Push commands
    if($currentObject.GetType().FullName -eq "GitCommit"){

        # Remove files except README.md and .git. This is done to create a clean working directory for the upcoming git commit
        # Change permissions on every file except README.md and .git
        Get-Childitem -Recurse -Path "$workingFolder/$gitFolderName" -exclude README.md,.git | where { !$_.PSisContainer } |Set-ItemProperty -Name IsReadOnly -Value $false
        # Remove files
        Get-ChildItem -Path "$workingFolder/$gitFolderName" -Recurse -exclude README.md |
        Select -ExpandProperty FullName |
        Where {$_ -notlike "$workingFolder/$gitFolderName/.git"} |
        sort length -Descending |
        Remove-Item -Recurse -force

        # Load and stage files
        Set-Content "GitCommands.sh" "cd $gitFolderName" -force
        Add-Content "GitCommands.sh" "$($currentObject.VSSFilesCommand)"
        Add-Content "GitCommands.sh" "git add --all"
        Add-Content "GitCommands.sh" "git commit -m `"$($currentObject.message)`""

        # Change Committer's name
        Add-Content "GitCommands.sh" "git commit --amend --date `"$($currentObject.timeStamp) +0000`" --no-edit"
        Add-Content "GitCommands.sh" "git commit --amend --author `"$($currentObject.userName) <$($currentObject.userName)@unisys.com>`" --no-edit"

        # Change Commit's date
        Add-Content "GitCommands.sh" "export GIT_COMMITTER_DATE=`"$($currentObject.timeStamp) +0000`""
        Add-Content "GitCommands.sh" "git commit --amend --no-edit"

        # Pushes to defined branch of the Git repository
        Add-Content "GitCommands.sh" "git push origin $gitBranchName -f"
    }

    # Else object is a Git Tag object. Call Git tag commands
    elseif($currentObject.GetType().FullName -eq "GitTag"){
        # Set Tagger name, email, and commit date
        Set-Content "GitCommands.sh" "cd $gitFolderName" -force
        Add-Content "GitCommands.sh" "git config --global user.name `"$($currentObject.userName)`""
        Add-Content "GitCommands.sh" "git config --global user.email `"$($currentObject.userName)@unisys.com`""
        Add-Content "GitCommands.sh" "set GIT_COMMITTER_DATE=`"$($currentObject.timeStamp) +0000`""

        # Create and push annotated Git Tag
        Add-Content "GitCommands.sh" "git tag -a `"$($currentObject.title)`" -m `"$($currentObject.message)`""
        Add-Content "GitCommands.sh" "git push origin $gitBranchName --tags"
    }

    Add-Content "GitCommands.sh" "sleep 2"
    # Send report to log file
    Add-Content "OverallLog.txt" "******** $commitCounter ********"
    Get-Content "GitCommands.sh" | Add-Content "OverallLog.txt"
    Add-Content "OverallLog.txt" "`n`n"
    # Execute git commands script
    Start-Process -FilePath "$gitBashPath" -ArgumentList  "-l $workingFolder/GitCommands.sh" -Wait
    $commitCounter++
}

# Delete no longer needed log files
Remove-Item $UniqueVSSCheckinLog
Remove-Item "GitCommands.sh"
