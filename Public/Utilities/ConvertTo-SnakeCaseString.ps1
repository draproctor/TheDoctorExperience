function ConvertTo-SnakeCaseString {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline = $true)]
    [string]$InputString
  )

  process {
    $pattern =
      [regex]'[A-Z]{2,}(?=[A-Z][a-z]+[0-9]*|\b)|[A-Z]?[a-z]+[0-9]*|[A-Z]|[0-9]+'
    [string]::Join('_', $pattern.Matches($InputString).Value).ToLower()
  }
}
