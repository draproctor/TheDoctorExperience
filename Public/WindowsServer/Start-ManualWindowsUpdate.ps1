function Start-ManualWindowsUpdate {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateFileExists()]
    [string] $Path,

    [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
    [string] $BinaryPath = 'C:\Windows\System32\wusa.exe'
  )

  process {
    $startInfo = [System.Diagnostics.ProcessStartInfo]@{
      FileName = $BinaryPath
      CreateNoWindow = $true
      RedirectStandardError = $true
      RedirectStandardOutput = $true
      UseShellExecute = $false
      WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
      Arguments = "$Path /quiet /norestart"
    }

    $installer = [System.Diagnostics.Process]::new()
    $installer.StartInfo = $startInfo

    try {
      $isProcessStarted = $installer.Start()

      if (!$isProcessStarted) {
        "Failed to start $BinaryPath." | Write-Warning
        return
      }

      'Waiting for the install to finish' | Write-Verbose -Verbose
      $installer.WaitForExit()
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
}
