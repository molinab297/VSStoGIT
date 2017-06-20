. C:/Users/MolinaBA/Desktop/GitObject.ps1

#################################### Flowchart of VSStoGit process #####################################################
# Get VSS history ---> Get Unique VSS history --> Create List of Git Commit/Tag Objects --> Migrate VSS Repository to Git
########################################################################################################################

################################## Script Set-Up Variables ################################
## ----------------------------------------------------------------------------------------

# Tell script where to place working folder
$workingFolder = New-Item "C:/Users/MolinaBA/Desktop/VSS2Git" -ItemType directory -force
cd $workingFolder

# Tell script what repository to clone from
$gitRepositoryURL = "https://MolinaBA@USTR-GITLAB-1.na.uis.unisys.com/MCPTest/GitMigration-Test.git"

# Tell script what Git branch to push data to
$gitBranchName = "00"

# Tell script the name of the Git project (the one that was cloned)
$gitFolderName = "GitMigration-Test"

git config --global http.sslVerify false
git clone -b $gitBranchName $gitRepositoryURL

# Tell script what VSS repository to pull data from
$VSS_ServerName = "$/00/NXPipe"
$VSSHistory     = ss History $VSS_ServerName -R # Grab VSS history

## ----------------------------------------------------------------------------------------
###########################################################################################

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
$content     = get-content "$workingFolder/$HistoryFileName" | select-string -Pattern  "Date:(.*)/(.*)/(([0][5-9])|([1][0-9]))(.*)"

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
    $commit_stats = $commit_stats -split "\s+"

    # If the checkin is a VSS Label
    if($checkin -match "Label:"){

        # Create new Git Tag object
        $newGitTag = New-Object GitTag

        # Extract VSS Label title
        $tagName = $checkin | select-string -Pattern "Label:"
        $tagName = $tagName -Replace 'Label:',''

        # Extract VSS Label comment
        $tagComment = $checkin | select-string -Pattern "Label comment:"
        $tagComment = $tagComment -Replace 'Label comment:','' # Remove unnecessary 'Label comment:'

        # VSS label message is empty
        if($tagComment -eq $Null){
            $tagComment = "No comment for this tag"
        }

        # Fill Git Tag object with extracted VSS label info
        $newGitTag.title    = $tagName
        $newGitTag.message  = $tagComment
        $newGitTag.userName = $commit_stats[0]
        $newGitTag.date     = $commit_stats[1]
        $newGitTag.time     = $commit_stats[2]

        # Push Git Tag object onto list
        $gitObjectList.Add($newGitTag) > $null
    }

    # Else this must be a normal VSS file checkin
    else{

        # Create new Git Commit object
        $newGitCommit = New-Object GitCommit

        # Get VSS Checkin message
        $comment = $checkin | Out-String

        # If a VSS Checkin comment exists, extract it. Else set default message
        if($comment -match "Comment:((.|\n)*)"){
            $comment = $Matches[0]
        }
        else{
            $comment = "No comment for this commit"
        }

        $commitComment = $comment -Replace 'Comment:','' # Remove unnecessary 'Comment:'

        # Fill Git Commit object with extracted VSS Checkin info
        $newGitCommit.userName        = $commit_stats[0]
        $newGitCommit.date            = $commit_stats[1]
        $newGitCommit.time            = $commit_stats[2]
        $newGitCommit.message         = $commitComment
        $newGitCommit.VSSFilesCommand = $command

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

New-Item "GitCommands.cmd" -type file -force # Create Git command file that will be executed
New-Item "OverallLog.txt" -type file -force  # Create log file which will contain every git commit/git tag command that is executed

# Loop through gitObjectList and add each git commit/tag (in order) to the cloned git repository
ForEach($currentObject in $gitObjectList){

    # If the current object is a Git Commit object, then call Git Add, Commit, Push commands
    if($currentObject.GetType().FullName -eq "GitCommit"){

        # Load and stage files
        Set-Content "GitCommands.cmd" "cd $gitFolderName" -force
        Add-Content "GitCommands.cmd" "$($currentObject.VSSFilesCommand)"
        Add-Content "GitCommands.cmd" "git add --all"
        Add-Content "GitCommands.cmd" "git commit -m `"$($currentObject.message)`""

        # Change Commit's Author name and date
        Add-Content "GitCommands.cmd" "git commit --amend --author `"$($currentObject.userName) <$($currentObject.userName)@email.com>`" --no-edit"
        Add-Content "GitCommands.cmd" "git commit --amend --date `"$($currentObject.date) $($currentObject.time) -0700`" --no-edit"

        # Change Commit's date
        Add-Content "GitCommands.cmd" "set GIT_COMMITTER_DATE=`"$($currentObject.date) $($currentObject.time) -0700`""
        Add-Content "GitCommands.cmd" "git commit --amend --no-edit"

        # Pushes to defined branch of the Git repository
        Add-Content "GitCommands.cmd" "git push origin $gitBranchName"
    }

    # Else object is a Git Tag object. Call Git tag commands
    elseif($currentObject.GetType().FullName -eq "GitTag"){

        Set-Content "GitCommands.cmd" "cd $gitFolderName" -force

        # Set Tagger name, email, and commit date
        Add-Content "GitCommands.cmd" "git config --global user.name `"$($currentObject.userName)`""
        Add-Content "GitCommands.cmd" "git config --global user.email `"$($currentObject.userName)@email.com`""
        Add-Content "GitCommands.cmd" "set GIT_COMMITTER_DATE=`"$($currentObject.date) $($currentObject.time) -0700`""

        # Create and push annotated Git Tag
        Add-Content "GitCommands.cmd" "git tag -a`"$($currentObject.title)` -m `"$($currentObject.message)`" "
        Add-Content "GitCommands.cmd" "git push origin $gitBranchName --tags"
    }

    Add-Content "GitCommands.cmd" "sleep 3"
    # Send report to log file
    Get-Content "GitCommands.cmd" | Add-Content "OverallLog.txt"
    Add-Content "OverallLog.txt" "`n`n"
    # execute git commands script
    cmd.exe /C 'GitCommands.cmd'
}

# Delete no longer needed log files
Remove-Item $UniqueVSSCheckinLog
Remove-Item "GitCommands.cmd"
