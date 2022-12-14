function Get-ScheduledTaskHistory {
  <#
  .SYNOPSIS
    Find the Windows events that correlate to a specific scheduled task.
  .DESCRIPTION
    Find the Windows events that correlate to a specific scheduled task.
  .PARAMETER TaskName
    Name of s scheduled task to find events for.
  .PARAMETER ComputerName
    Host name of thr remote computer to find events on.
  .PARAMETER StartTime
    Not implemented.
  .PARAMETER EndTime
    Not implemented.
  .PARAMETER MaxEvents
    Number of maximum events to return.
  .PARAMETER Uri
    URI path to a scheduld task.
  #>
  [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [string] $TaskName,

    [string[]] $ComputerName,

    [datetime] $StartTime = [datetime]::Now.AddDays(-7),

    [datetime] $EndTime = [datetime]::Now,

    [ValidateRange(0, [int64]::MaxValue)]
    [int64] $MaxEvents = 100,

    [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ByUri')]
    [ValidateNotNullOrEmpty()]
    [string] $Uri
  )

  process {
    $taskNameQuery = "\$TaskName"
    if ($PSBoundParameters.ContainsKey('Uri')) {
      $taskNameQuery = $Uri
    }

    # We have to use XML to find a scheduled task by its name in PowerShell 5.1.
    # In PowerShell 6+, we can use -FilterHashTable.
    if ($PSVersionTable.PSVersion.Major -gt 6) {
      $splat = @{ TaskName = $taskNameQuery }
    } else {
      # Let's get fancy for no good reason. I don't want to deal with the weird
      # identation of using a here-string.
      <#
      <QueryList>
        <Query Id="0" Path="Microsoft-Windows-TaskScheduler/Operational">
          <Select Path="Microsoft-Windows-TaskScheduler/Operational">
            *[EventData/Data[@Name='TaskName']='$taskNameQuery']
          </Select>
        </Query>
      </QueryList>
      #>
      $path = 'Microsoft-Windows-TaskScheduler/Operational'
      $queryList = [System.Xml.Linq.XElement]::new(
        'QueryList',
        [System.Xml.Linq.XElement]::new(
          'Query',
          [System.Xml.Linq.XAttribute]::new('Id', 0),
          [System.Xml.Linq.XAttribute]::new('Path', $path),
          [System.Xml.Linq.XElement]::new(
            'Select',
            [System.Xml.Linq.XAttribute]::new('Path', $path),
            "*[EventData/Data[@Name='TaskName']='$taskNameQuery']"
          )
        )
      )
      $splat = @{
        FilterXml = $queryList.ToString()
        MaxEvents = $MaxEvents
      }
    }

    if ($PSBoundParameters.ContainsKey('ComputerName')) {
      return Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $splat = $using:splat
        Get-WinEvent @splat
      }
    }

    Get-WinEvent @splat
  }
}
