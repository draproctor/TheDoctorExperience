function Get-EnumHashtable {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [ValidateScript( { $_.BaseType.Name -eq 'Enum' })]
    [type] $Enum
  )

  process {
    $collection = @{ }
    foreach ($name in [enum]::GetValues($enum)) {
      $collection[$name.ToString()] = $name.value__
    }
    return $collection
  }
}
