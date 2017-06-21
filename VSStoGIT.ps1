. C:/Users/MolinaBA/Desktop/GitObject.ps1

#################################### Flowchart of VSStoGit process #####################################################
# Get VSS history ---> Get Unique VSS history --> Create List of Git Commit/Tag Objects --> Migrate VSS Repository to Git
########################################################################################################################

################################## Script Set-Up Variables ################################
## ----------------------------------------------------------------------------------------

# Tell script where to place working folder
$workingFolder = New-Item "C:/Users/MolinaBA/Desktop/VSStoGit" -ItemType directory -force

# Tell script what Git repository to push data to
$gitRepositoryURL = "https://MolinaBA@USTR-GITLAB-1.na.uis.unisys.com/MCPTest/NXPipe-GitMigration-Test.git"

# Tell script what Git branch to push data to
$gitBranchName = "00"

# Tell script the name of the Git project (the one that was cloned)
$gitFolderName = "NXPipe-GitMigration-Test"

# Tell script what VSS repository to pull data from
$VSS_ServerName = "`"$\00\NXPipe`""

## ----------------------------------------------------------------------------------------
###########################################################################################

# Setup working folder
cd $workingFolder
git config --global http.sslVerify false
git clone -b $gitBranchName $gitRepositoryURL
$VSSHistory = ss History $VSS_ServerName -R # Grab VSS history

#######################  Create Unique VSS Checkin Log ##########################
# Purpose: This section constructs a list of Git Tag and Git Commit objects. It does
# this by iterating through $UniqueVSSCheckinLog (which is a text file containing
# unique SourceSafe checkins by date and time), and determining if the checkin is
# a file checkin or a label checkin.
#
#   INPUT:
#     - $VSSHistory : A text file (probably very large) that contains every single
#     VSS checkin.
#
#   OUTPUT:
#     - $UniqueVSSCheckinLog : A text file (much smaller) that contains only unique
#     VSS file and label checkins by date and time
#################################################################################

# Place VSS History in a text file and then move that file into the working folder
$HistoryFileName = "VSSHistory.txt"
New-Item "$workingFolder/$HistoryFileName" -type file
New-Item "temp.txt" -type file
add-content -path "$workingFolder/$HistoryFileName" -value $VSSHistory
get-content $HistoryFileName | select -Skip 2 | set-content "temp.txt" # Remove unnecessary 'Building list...' part of VSS History log
move "temp.txt" $HistoryFileName -force


# Create a new text file that only contains unique VSS checkin dates/times
$UniqueVSSCheckinLog = "VSSCheckinLog-Unique.txt"
New-Item "$workingFolder/$UniqueVSSCheckinLog" -type file

# Get VSS checkins with dates that are greater to or equal than 2005
$content = get-content "$workingFolder/$HistoryFileName" | select-string -Pattern  "Date:(.*)/(.*)/(([0][5-9])|([1][0-9]))(.*)"

# Reverse date/time content (Git commands will be performed starting from 2005-Present)
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
## get the source/label files from VSS that were checked in at that exact date and time.
for($index = 0; $index -lt $date.Length; $index++) {
    $Different_Time = !($time[$index] -match $time[($index+1)]) -or !($time[($index+1)])
    $Same_Time_Diff_Date = ($time[$index] -match $time[($index+1)]) -and !($date[$index] -match $date[($index+1)])
    if($Different_Time -or $Same_Time_Diff_Date){
      $uniqueDate  = "ss Get $VSS_ServerName -R -Vd$($newDate[$index])"";""$($time[$index]) -I-N" # Creates SourceSafe command to get file by dates & time
      add-content "$workingFolder/$UniqueVSSCheckinLog" $uniqueDate -force
    }
}


#######################  Construct Git Object List ##############################
# Purpose: This section constructs a list of Git Tag and Git Commit objects. It does
# this by iterating through $UniqueVSSCheckinLog (which is a text file containing
# unique SourceSafe checkins by date and time), and determining if the checkin is
# a file checkin or a label checkin.
#
#   INPUT:
#     - $UniqueVSSCheckinLog : A text file containing unique VSS checkin date/times
#
#   OUTPUT:
#     - $gitObjectList : A list of Git Tag and Git Commit objects
#################################################################################

# Create empty list to store Git Commit and Git Tag objects
$gitObjectList = New-Object System.Collections.ArrayList

ForEach($checkin in Get-Content $workingFolder/$UniqueVSSCheckinLog){
    $command = $checkin
    $checkin = $checkin -Replace 'Get','History'           # prepare vss history command
    $checkin += " -#1"                                     # Append command flag to only display 1 entry
    $checkin = invoke-expression $checkin | select -Skip 2 # run the vss history command and store the output

    # Handles when the stupid SourceSafe Command line utility doesnt work (i.e. error "Version not found")
    if($checkin -eq $Null){Continue}

    # Extract VSS Checkin User, Date, and Time info
    $commit_stats = $checkin | select-string -Pattern "User:"
    $commit_stats = $commit_stats -Replace 'User: ',''
    $commit_stats = $commit_stats -Replace 'Date: ',''
    $commit_stats = $commit_stats -Replace 'Time: ',''
    $commit_stats = $commit_stats -split "\s+" # Splits User, Date, & Time into an array

    # Get Unix time stamp. Pass in the Date and Time as parameters.
    $unixTimeStamp = GetUnixTimeStamp $commit_stats[1] $commit_stats[2]

    # If the checkin is a VSS Label
    if($checkin -match "Label:"){

        # Create new Git Tag object
        $newGitTag = New-Object GitTag

        # Extract VSS Label title
        $tagName = $checkin | select-string -Pattern "Label:"
        $tagName = $tagName -Replace 'Label:',''
        $tagName = $tagName -Replace ' ', '' # Remove all whitespace (Git tags don't allow whitespace)
        $tagName = $tagName -Replace '"', ''

        # Extract VSS Label comment
        $tagComment = $checkin | select-string -Pattern "Label comment:"
        $tagComment = $tagComment -Replace 'Label comment:','' # Remove unnecessary 'Label comment:'

        # VSS label message is empty
        if($tagComment -eq $Null){
            $tagComment = "No comment for this tag"
        }

        # Fill Git Tag object with extracted VSS label info
        $newGitTag.title     = $tagName
        $newGitTag.message   = $tagComment
        $newGitTag.userName  = $commit_stats[0]
        $newGitTag.timeStamp = $unixTimeStamp

        # Push Git Tag object onto list
        $gitObjectList.Add($newGitTag) > $null
    }

    # Else this must be a normal VSS file checkin
    else{

        # Create new Git Commit object
        $newGitCommit = New-Object GitCommit

        # Get VSS Checkin message
        $commitComment = $checkin | Out-String

        # If a VSS Checkin comment exists, extract it. Else set default message
        if($commitComment -match "Comment:((.|\n)*)"){
            $commitComment = $Matches[0]
            $commitComment = $commitComment -Replace 'Comment:','' # Remove unnecessary 'Comment:'
            $commitComment = $commitComment.Trim() # Remove unnecessary white space
            if(([string]::IsNullOrEmpty($comment))){
                $commitComment = "No comment for this commit"
            }
        }
        else{
            $commitComment = "No comment for this commit"
        }

        # Fill Git Commit object with extracted VSS Checkin info
        $newGitCommit.userName        = $commit_stats[0]
        $newGitCommit.message         = $comment
        $newGitCommit.VSSFilesCommand = $command
        $newGitCommit.timeStamp       = $unixTimeStamp

        # Push Git Commit object onto list
        $gitObjectList.Add($newGitCommit) > $null
    }
}

###################### Git Repository Construction ###############################
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
##################################################################################

New-Item "GitCommands.sh" -type file -force # Create Git command file that will be executed
New-Item "OverallLog.txt" -type file -force  # Create log file which will contain every git commit/git tag command that is executed
$commitCounter = 1 # For displaying commit number on top of each commit in OverallLog.txt

# Loop through gitObjectList and add each git commit/tag (in order) to the cloned git repository
ForEach($currentObject in $gitObjectList){

    # If the current object is a Git Commit object, then call Git Add, Commit, Push commands
    if($currentObject.GetType().FullName -eq "GitCommit"){

        # Remove files except README.md and .git. This is done to create a clean working directory for the upcoming git commit
        # First need to change permissions on every file except README.md and .git
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
        Add-Content "GitCommands.sh" "git commit --amend --author `"$($currentObject.userName) <$($currentObject.userName)@email.com>`" --no-edit"

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
        Add-Content "GitCommands.sh" "git config --global user.email `"$($currentObject.userName)@email.com`""
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
    # execute git commands script
    Start-Process -FilePath "C:\Program Files\Git\bin\sh.exe" -ArgumentList  "-l $workingFolder\GitCommands.sh" -Wait
    $commitCounter++
}

# Delete no longer needed log files
Remove-Item $UniqueVSSCheckinLog
Remove-Item "GitCommands.sh"
