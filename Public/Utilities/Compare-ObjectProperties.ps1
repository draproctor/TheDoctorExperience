function Compare-ObjectProperties {
  <#
Based on - https://blogs.technet.microsoft.com/janesays/2017/04/25/compare-all-properties-of-two-objects-in-windows-powershell/
#>
  [CmdletBinding(DefaultParameterSetName = "Default")]
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [psobject] $ReferenceObject,

    [Parameter(Mandatory = $true, Position = 1)]
    [psobject] $DifferenceObject,

    [switch] $IncludeNonSettableProperties,

    [string[]] $ExcludeProperties,

    [Parameter(Mandatory = $false, ParameterSetName = "ReferenceOnly")]
    [Alias('RefValuesOnly', 'RefsOnly')]
    [switch] $ReturnReferenceValuesOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "DifferenceOnly")]
    [Alias('DiffValuesOnly', 'DiffsOnly')]
    [switch] $ReturnDifferenceValuesOnly,

    [Parameter(Mandatory = $false, ParameterSetName = "ReferenceOnly")]
    [Parameter(Mandatory = $false, ParameterSetName = "DifferenceOnly")]
    [Alias('HashTable')]
    [switch] $AsHashTable # Useful in generating a splat of deltas
  )

  # String used to match either settable props only (set;) or all properties (.)
  if ($IncludeNonSettableProperties -eq $false) {
    $strSettable = 'set;'
  }

  # String array used to select what data should be returned in final output
  if ($ReturnReferenceValuesOnly) {
    $strSelect = 'PropertyName', 'RefValue'
  } elseif ($ReturnDifferenceValuesOnly) {
    $strSelect = 'PropertyName', 'DiffValue'
  } else {
    $strSelect = 'PropertyName', 'RefValue', 'DiffValue'
  }

  # Find all Property and NoteProperty members for both Ref and Diff objects
  $arrProperties = $ReferenceObject, $DifferenceObject |
    Get-Member -MemberType 'Property', 'NoteProperty' |
    Where-Object -FilterScript {
      $_.Definition -match $strSettable -and
      $_.Name -notin $ExcludeProperties
    } |
    Select-Object -ExpandProperty 'Name' -Unique |
    Sort-Object

  # Compare properties
  $diffs = $(
    foreach ($Property in $arrProperties) {
      $diff = Compare-Object $ReferenceObject $DifferenceObject -Property $Property
      if ($diff) {
        [psobject]@{
          PropertyName = $Property
          RefValue = $diff |
            Where-Object -FilterScript { $_.SideIndicator -eq '<=' } |
            Select-Object -ExpandProperty $Property
          DiffValue = $diff |
            Where-Object -FilterScript { $_.SideIndicator -eq '=>' } |
            Select-Object -ExpandProperty $Property
        }
      }
    }
  ) | Select-Object -Property $strSelect

  if ($diffs) {
    if ($AsHashTable) {
      $hashDiffs = @{}
      $diffs | ForEach-Object {
        $hashDiffs.Add($_.PropertyName, $_."$($strSelect[-1])")
      }
      return $hashDiffs
    }
    return ($diffs | Select-Object -ExcludeProperty 'SideIndicator')
  }
}
