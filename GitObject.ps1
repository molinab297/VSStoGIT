# Represents a Git Commit Object
Class GitCommit{
    [String]$message
    [String]$userName
    [String]$date
    [String]$time
    [String]$VSSFilesCommand # Contains a VSS Get command that grabs every file according to the specified date and time.
}

# Represents a Git Tag Object
Class GitTag{
    [String]$title
    [String]$userName
    [String]$message
    [String]$date
    [String]$time
}
