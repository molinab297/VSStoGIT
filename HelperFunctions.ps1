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

################# Function SubtractByOneMin ####################
# Purpose: Subtracts a timestamp, in format MM\DD\YY HH:MM, by
# 1 minute.
#
# INPUT:
#   - [string]$date : Date in 'MM\DD\YY' format
#   - [string]$time : Time in 'HH:MM A\P' format
#
# RETURNS:
#   - [string]$dateTime : A string containing the date minus 1
#     minute
#
###############################################################
Function SubtractByOneMin {
param([string]$date,[string]$time)
      $time = $time -Replace 'p','pm'
      $time = $time -Replace 'a','am'
      $dateObject = [datetime]"$date $time"
      $dateObject = $dateObject.AddMinutes(-1)
      $dateTime = "{0:MM/dd/yy hh:mmtt}" -f $dateObject
      $dateTime = $dateTime -Replace '/','-'
      $dateTime = $dateTime -replace 'PM','p'
      $dateTime = $dateTime -replace 'AM','a'
      return $dateTime
}
