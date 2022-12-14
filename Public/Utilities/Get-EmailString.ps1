function Get-EmailString {
  <#
  .SYNOPSIS
    Retrieve all instances of an email from any string.
  .DESCRIPTION
    Get-EmailString retrieves all unique instances of an email address in a
    given string. It automatically replaces the 'mailto:' string with whitespace
    so that the two emails are not confused. To show all regexMatches matched,
    use the -ShowDuplicates parameter.
  .EXAMPLE
    PS C:\> 'testing@foo.commailto:testing@foo.com' | Get-EmailString
    testing@foo.com

    PS C:\> 'bar@foo.commailto:bar@foo.com' | Get-EmailString -ShowDuplicates
    testing@foo.com
    testing@foo.com
  .EXAMPLE
    Some cmdlets only accept email-like values if they belong to an object with
    a specific property. The -As parameter gives you the ability to create
    custom objects with arbirtary properties mapped to the emails pullled from
    strings.

    PS C:\> 'John Smith jsmith@foo.bar; Jane Doe jdoe@foo.bar' |
      Get-EmailString -As 'UserPrincipalName' |
      Get-MsolUser

    Returns MsolUser objects.
  .INPUTS
    System.String
  .OUTPUTS
    System.String
  .NOTES
    By default, Get-EmailString removes 'mailto:' from strings. To stop this
    behavior, set the -RemoveMailToString parameter to $false.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $InputString,

    [string] $As,

    [bool] $RemoveMailToString = $true,

    [switch] $ShowDuplicates
  )

  begin {
    # Create regex matching object.
    $regex = [regex]::new(
      '\w+([-+.'']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*',
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
  }

  process {
    # Process matches.
    if ($RemoveMailToString) {
      $InputString = $InputString -replace 'mailto(:)?', ' '
    }

    $regexMatches = $regex.Matches($InputString).Value

    if ($ShowDuplicates.IsPresent) {
      # Emails are not case sensitive, so we downcase to remove dupes.
      $results = $regexMatches.ToLower()
    } else {
      $results = $regexMatches.ToLower() | Select-Object -Unique
    }

    foreach ($r in $results) {
      # Return custom object for cmdlets down the pipeline.
      if (
        $PSBoundParameters.ContainsKey('As') -and
        ![string]::IsNullOrEmpty($As)
      ) {
        [PSCustomObject]@{ $As = $r.ToString() }
      } else {
        $r.ToString()
      }
    }
  }
}
