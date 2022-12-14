Function Get-PendingReboot {
  Param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string[]] $ComputerName
  )

  Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    $baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
      'LocalMachine',
      $ComputerName
    )

    $result = [pscustomobject]@{
      Cause = [System.Collections.Generic.List[string]]::new()
      RebootPending = $false
    }

    @(
      'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\'
      'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\'
    ) | ForEach-Object {
      $key = $baseKey.OpenSubKey($_)
      $rebootPendingKeys = $key.GetSubKeyNames() |
        Where-Object { $_ -in 'RebootPending', 'RebootRequired' }
      $key.Close()

      if ($null -ne $rebootPendingKeys) {
        $result.Cause.Add($_)
        $result.RebootPending = $true
      }
    }

    $sessionKeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $getItemPropertySplat = @{
      Path = $sessionKeyPath
      Name = 'PendingFileRenameOperations'
      ErrorAction = 'SilentlyContinue'
    }
    $renamedFiles = Get-ItemProperty @getItemPropertySplat
    if ($renamedFiles) {
      $result.Cause.Add($renamedFiles.PendingFileRenameOperations -join ', ')
      $result.RebootPending = $true
    }

    if (!$result.RebootPending) {
      $result.Cause = 'N/A'
    }

    $result
  }
}
