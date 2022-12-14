function Get-StringChecksum {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [string] $InputString,

    [System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8
  )

  process {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash($Encoding.GetBytes($InputString))
    [System.BitConverter]::ToString($hash).Replace('-', '')
  }
}
