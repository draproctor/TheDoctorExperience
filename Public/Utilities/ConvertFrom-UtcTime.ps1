function ConvertFrom-UtcTime {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Time
  )

  process {
    return [datetime]::SpecifyKind($Time, [System.DateTimeKind]::Utc)
  }
}
