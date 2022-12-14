function Copy-DexLocalModule {
  [CmdletBinding()]
  param (
    [string] $Name,

    [string] $Root = '\\tsclient'
  )

  process {
    $source = "$Root\it-bin\shelves\ps_modules\$Name\Output\$Name"
    $destination = [System.IO.Path]::Combine(
      'C:\Program Files\WindowsPowerShell\Modules',
      $Name
    )

    if (![System.IO.Directory]::Exists($source)) {
      "Source module doesn't exist: $source" | Write-Warning
      return
    }

    $latestVersion = Get-ChildItem -Path $source -Directory |
      Sort-Object -Property { [version]$_.Name } |
      Select-Object -Last 1

    $copySplat = @{
      Path = $latestVersion.FullName
      Destination = $destination
      Recurse = $true
      Force = $true
      ErrorAction = 'Stop'
    }
    try {
      Copy-Item @copySplat
      "Moved $Name $($latestVersion.Name) successfully" | Write-Verbose -Verbose
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
}
