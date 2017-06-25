. C:/Users/MolinaBA/Desktop/VSStoGIT/HelperFunctions.ps1

# Represents a Git Commit object
Class GitCommit{
    [String]$message
    [String]$userName
    [String]$timeStamp # Unix formatted timestamp
    [String]$VSSFilesCommand
}

# Represents a Git Tag object
Class GitTag{
    [String]$title
    [String]$userName
    [String]$message
    [String]$timeStamp # Unix formatted timestamp
}


Function CreateGitCommit{
param([string]$checkinCommand)

    # Add '-L-' flag, which tells VSS command line utility to only output non-label checkins
    $command = $checkinCommand -Replace '-R','-L- -R'
    # Add -#1 flag at end of command, which tells the VSS command line utility to only display 1 entry
    $command += " -#1"
    # run the vss history command and store the output
    $checkin = invoke-expression $command | select -Skip 3

    if(([string]::IsNullOrEmpty($checkin))){
       $command = $command -Replace ' -#1', ''
       $checkin = invoke-expression $command | select -Skip 3
    }

    $checkinCommand = $checkinCommand -Replace 'History','Get'

    # Extract VSS Checkin User, Date, and Time info
    $commit_stats = $checkin | select-string -Pattern "User:"
    $commit_stats = $commit_stats -Replace 'User: ',''
    $commit_stats = $commit_stats -Replace 'Date: ',''
    $commit_stats = $commit_stats -Replace 'Time: ',''
    $commit_stats = $commit_stats -split "\s+" # Splits User, Date, & Time into an array

    # Get Unix time stamp. Pass in the Date and Time as parameters.
    $unixTimeStamp = GetUnixTimeStamp $commit_stats[1] $commit_stats[2]

    # Create new Git Commit object
    $newGitCommit = New-Object GitCommit

    # Get VSS Checkin message
    $comment = $checkin | Out-String

    # If a VSS Checkin comment exists, extract it. Else set default message
    if($comment -match "Comment:((.|\n)*)"){
         $comment = $Matches[0]
         $comment = $comment -Replace 'Comment:','' # Remove unnecessary 'Comment:'
         $comment = $comment.Trim() # Remove unnecessary white space
         if(([string]::IsNullOrEmpty($comment))){
             $comment = "No comment for this commit"
          }
    }
    else{
      $comment = "No comment for this commit"
    }

    # Fill Git Commit object with extracted VSS Checkin info
    $newGitCommit.userName        = $commit_stats[0]
    $newGitCommit.message         = $comment
    $newGitCommit.VSSFilesCommand = $checkinCommand
    $newGitCommit.timeStamp       = $unixTimeStamp

    return $newGitCommit
}


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
    $commit_stats = $commit_stats -split "\s+" # Splits User, Date, & Time into an array

    # Get Unix time stamp. Pass in the Date and Time as parameters.
    $unixTimeStamp = GetUnixTimeStamp $commit_stats[1] $commit_stats[2]

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
