function Get-OUString {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string] $DistinguishedName
  )

  begin {
    $regex = [regex]::new('(?!CN=.*,)OU=.*')
  }

  process {
    return $regex.Match($DistinguishedName).Value
  }
}
