function Clear-WindowsUpdateDownload {
  [CmdletBinding()]
  param (
    [string] $ComputerName
  )

  process {
    $clearDownload = {
      $path = 'C:\Windows\SoftwareDistribution\Download\'
      $svcs = Get-Service -Name 'bits', 'wuauserv'
      $svcs | Stop-Service -Force
      Remove-Item -Path $path -Recurse -Force
      $svcs | Start-Service
    }

    if ($PSBoundParameters.ContainsKey('ComputerName')) {
      Invoke-Command -ComputerName $ComputerName -ScriptBlock $clearDownload
    } else {
      $clearDownload.Invoke()
    }
  }
}
