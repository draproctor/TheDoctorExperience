function ConvertTo-LocalTime {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $ParseFrom,

    [Parameter(ParameterSetName = 'Parse')]
    [System.DateTimeKind] $Kind = [System.DateTimeKind]::Utc
  )

  process {
    $time = [datetime]::Parse($ParseFrom)
    return [datetime]::SpecifyKind($time, $Kind).ToLocalTime()
  }
}
