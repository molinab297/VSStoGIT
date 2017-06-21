# Represents a Git Commit Object
Class GitCommit{
    [String]$message
    [String]$userName
    [String]$timeStamp       # format is a Unix timestamp
    [String]$VSSFilesCommand # Contains a VSS Get command that grabs every file according to the specified date and time.
}

# Represents a Git Tag Object
Class GitTag{
    [String]$title
    [String]$userName
    [String]$message
    [String]$timeStamp # format is a Unix timestamp
}

################# Function GetUnixTimeStamp ####################
# Purpose: Git accepts 3 types of time formats when modifying
# the date/time of Git Commits. The Unix time stamp format is
# one of these time formats. This function converts date and time
# into a Unix time stamp.
#
# INPUT:
#   - [string]$date : Date in 'MM\DD\YY' format
#   - [string]$time : Time in 'HH:MM A\P' format
#
# RETURNS:
#   - $unixTimeStamp : A timestamp in Unix format
#
###############################################################
Function GetUnixTimeStamp{
param([string]$date,[string]$time)

  $time = $time -Replace 'A','AM'
  $time = $time -Replace 'P','PM'
  # convert time to military time
  $militaryTime =  "{0:HH:mm}" -f [datetime]"$time"
  # convert military time to seconds
  $militaryTime_to_seconds = ([timespan]"$($militaryTime):00.00").TotalSeconds
  # convert date from vss file to seconds since epoch
  $date_to_seconds = (New-TimeSpan -Start "01/01/1970" -End $date).TotalSeconds
  # add both seconds together and bam theres the date/time converted to a unix timestamp
  $unixTimeStamp = $date_to_seconds + $militaryTime_to_seconds

  return $unixTimeStamp
}
