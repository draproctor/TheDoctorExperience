function Update-DesiredContent {
  [CmdletBinding()]
  param (
    [string] $Path,

    [string] $Content,

    [System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8
  )

  process {
    if (![System.IO.File]::Exists($Path)) {
      [System.IO.File]::WriteAllText($Path, $Content, $Encoding)
      return [PSCustomObject]@{
        Path = [System.IO.Path]::GetFullPath($Path)
        UpdatePerformed = $true
      }
    }

    # We can't use Get-FileHash because it doesn't read the file with UTF8.
    try {
      $currentHash = [System.IO.File]::ReadAllText($Path, $Encoding) |
        Get-StringChecksum -Encoding $Encoding
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
    $desiredHash = $Content | Get-StringChecksum -Encoding $Encoding

    $updatePerformed = $false

    if ($desiredHash -ne $currentHash) {
      try {
        [System.IO.File]::WriteAllText($Path, $Content, $Encoding)
        $updatePerformed = $true
      } catch {
        $PSCmdlet.ThrowTerminatingError($_)
      }
    }

    return [PSCustomObject]@{
      Path = [System.IO.Path]::GetFullPath($Path)
      UpdatePerformed = $updatePerformed
    }
  }
}
