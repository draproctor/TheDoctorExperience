function Get-DexCalendarDiagnosticObjects {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Identity,

    [Parameter(Mandatory)]
    [string] $Subject,

    [switch] $ExactMatch,

    [string] $StartDate,

    [string] $EndDate
  )

  $splat = @{
    Identity = $Identity
    Subject = $Subject
  }
  if ($ExactMatch.IsPresent) { $splat.Add('ExactMatch', $true) }
  if ($StartDate) { $splat.Add('StartDate', $StartDate) }
  if ($EndDate) { $splat.Add('EndDate', $EndDate) }

  $properties = @(
    @{
      Name = 'OLMT'
      Expression = {
        [datetime]::Parse($_.OriginalLastModifiedTime.ToString()).ToLocalTime()
      }
    }
    'OriginalCreationTime'
    'CalendarLogTriggerAction'
    'ItemClass'
    'ItemID'
    @{
      Name = 'MeetingID'
      Expression = { $_.CleanGlobalObjectId }
    }
    'ClientInfoString'
    'IsRecurring'
    'IsSeriesCancelled'
    'Location'
    'ResponseState'
    'SubjectProperty'
    'TimeZone'
    'ViewEndTime'
    'ViewStartTime'
    @{
      Name = 'ResponsibleUser'
      Expression = {
        $_.ResponsibleUserName.split('^/')[-1] -replace '(?s)^.*-|cn=', ''
      }
    }
    @{
      Name = 'Sender'
      Expression = {
        $_.SenderEmailAddress.split('^/')[-1] -replace '(?s)^.*-|cn=', ''
      }
    }
  )

  Get-CalendarDiagnosticObjects @splat |
    Select-Object -Property $properties |
    Sort-Object -Property 'OLMT'
}
