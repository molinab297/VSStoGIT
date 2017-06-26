. C:/Users/MolinaBA/Desktop/VSStoGIT/HelperFunctions.ps1

############################## Class GitCommit #############################
# Represents a Git Commit object
#
#   Class Variables:
#   [String]message         : Git commit message (VSS file checkin message)
#   [String]userName        : Git commit author name (VSS file checkin author)
#   [String]timeStamp       : Git commit timestamp (in unix format)
#   [String]VSSFilesCommand : A SourceSafe command to pull files from the VSS database.
#                              These files will be included in this Git commit
###########################################################################
Class GitCommit{
    [String]$message
    [String]$userName
    [String]$timeStamp
    [String]$VSSFilesCommand
}

############################## Class GitTag #############################
# Represents a Git Tag object
#
#   Class Variables:
#   [String]title     : Name of Git tag (VSS label name)
#   [String]userName  : Author of Git tag (Which is the user who created a VSS label)
#   [String]message   : Git tag message (VSS label message)
#   [String]timeStamp : Git tag timestamp (in unix format)
###########################################################################
Class GitTag{
    [String]$title
    [String]$userName
    [String]$message
    [String]$timeStamp
}


######################### Function CreateGitCommit #########################
# Creates a new Git commit object and returns it to the caller
#
#   DEPENDENCIES : HelperFunctions.ps1
#
#   INPUT:
#     [string]checkinCommand : A VSS command to dislay the history of the VSS file(s) checkin.
#                              Note that the history provides all the information needed
#                              to create the Git commit
#   OUTPUT:
#    [GitCommit] newGitCommit : A Git commit object with information (author,message,
#                               timestamp) from the history of the VSS file(s) checkin
###########################################################################
Function CreateGitCommit{
param([string]$checkinCommand)

    # Add '-L-' flag, which tells VSS command line utility to only output non-label checkins
    $command = $checkinCommand -Replace '-R','-L- -R'
    # Add -#1 flag at end of command, which tells the VSS command line utility to only display 1 entry
    $command += " -#1"
    # run the vss history command and store the output
    $checkin = invoke-expression $command | select -Skip 3

    # When the VSS command line utility refuses to output anything...
     if(([string]::IsNullOrEmpty($checkin))){
       # Try removing the '-#1' flag to see if the VSS CL utility outputs the checkin
        $command = $command -Replace ' -#1', ''
        $checkin = invoke-expression $command | select -Skip 3
        # On the off chance that the checkin is both a file & label checkin
        if(([string]::IsNullOrEmpty($checkin))){
             # Add '-L' flag to display VSS label information
             $command = $command -Replace ' -L-', '-L'
             $checkin = invoke-expression $command | select -Skip 3
         }
     }

    $checkinCommand = $checkinCommand -Replace 'History','Get'

    # Extract VSS Checkin User, Date, and Time info
    $commit_stats = $checkin | select-string -Pattern "User:"
    $commit_stats = $commit_stats -Replace 'User: ',''
    $commit_stats = $commit_stats -Replace 'Date: ',''
    $commit_stats = $commit_stats -Replace 'Time: ',''
    $commit_stats = $commit_stats -split "\s+"

    # Get Unix time stamp. Pass in the Date and Time as parameters.
    try{
        $unixTimeStamp = GetUnixTimeStamp $commit_stats[1] $commit_stats[2]
    }
    catch{Write-Host "Error with getting unix time stamp"}

    # Create new Git Commit object
    $newGitCommit = New-Object GitCommit

    # If a VSS Checkin comment exists, extract it. Else set default message
    $commitComment = $checkin | Out-String
    if($commitComment -match "Comment:((.|\n)*)"){
         $commitComment = $Matches[0]
         $commitComment = $commitComment -Replace 'Comment:','' # Remove unnecessary 'Comment:'
         $commitComment = $commitComment.Trim() # Remove unnecessary white space
         if(!([string]::IsNullOrEmpty($commitComment))){
          $commitComment = $commitComment -Replace '"', '' # Remove quotes from checkin comment (Quotes may screw up Git commit message)
          $commitComment = $commitComment -Replace '\*((.|\n)*)', '' # Remove extraneous checkins that may get caught in the commit comment
        }
        else{
          $commitComment = "No comment for this commit"
        }
    }
    else{
      $commitComment = "No comment for this commit"
    }

    # Fill Git Commit object with extracted VSS Checkin info
    $newGitCommit.userName        = $commit_stats[0]
    $newGitCommit.message         = $commitComment
    $newGitCommit.VSSFilesCommand = $checkinCommand
    $newGitCommit.timeStamp       = $unixTimeStamp

    return $newGitCommit
}


######################### Function CreateGitTag ###########################
# Creates a new Git tag object and returns it to the caller
#
#   DEPENDENCIES : HelperFunctions.ps1
#
#   INPUT:
#     [string]checkinCommand : A VSS command to dislay the history of the VSS label.
#                              Note that the history provides all the information needed
#                              to create the Git tag
#   OUTPUT:
#    [GitTag] newGitTag : A Git tag object with information (author,message,timestamp)
#                         from the history of the VSS label
###########################################################################
Function CreateGitTag{
param([string]$checkinCommand)

    # Add '-L' flag, which tells VSS command line utility to only output non-label checkins
    $checkinCommand = $checkinCommand -Replace '-R','-L -R'
    # Add -#1 flag at end of command, which tells the VSS command line utility to only display 1 entry
    $checkinCommand += " -#1"
    # run the vss history command and store the output
    $checkin = invoke-expression $checkinCommand | select -Skip 3

    # Extract VSS Checkin User, Date, and Time info
    $commit_stats = $checkin | select-string -Pattern "User:"
    $commit_stats = $commit_stats -Replace 'User: ',''
    $commit_stats = $commit_stats -Replace 'Date: ',''
    $commit_stats = $commit_stats -Replace 'Time: ',''
    $commit_stats = $commit_stats -split "\s+"

    # Get Unix time stamp. Pass in the Date and Time as parameters.
    # Get Unix time stamp. Pass in the Date and Time as parameters.
    try{
        $unixTimeStamp = GetUnixTimeStamp $commit_stats[1] $commit_stats[2]
    }
    catch{Write-Host "Error with getting unix time stamp"}

    # Create new Git Tag object
    $newGitTag = New-Object GitTag

    # Extract VSS Label title
    $tagName = $checkin | select-string -Pattern "Label:"
    $tagName = $tagName -Replace 'Label:',''

    # Remove symbols that Git does not allow in tag names
    $tagName = $tagName -Replace ' ', ''
    $tagName = $tagName -Replace '"', ''
    $tagName = $tagName -Replace ':',''

    # Extract VSS Label comment
    $tagComment = $checkin | select-string -Pattern "Label comment:"
    $tagComment = $tagComment -Replace 'Label comment:','' # Remove unnecessary 'Label comment:'

    # VSS label message is empty
    if(([string]::IsNullOrEmpty($tagComment))){
        $tagComment = "No comment for this tag"
    }

    # Fill Git Tag object with extracted VSS label info
    $newGitTag.title     = $tagName
    $newGitTag.message   = $tagComment
    $newGitTag.userName  = $commit_stats[0]
    $newGitTag.timeStamp = $unixTimeStamp

    return $newGitTag
}
