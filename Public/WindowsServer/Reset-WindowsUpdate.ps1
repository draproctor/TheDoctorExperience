function Reset-WindowsUpdate {
  <#
  .SYNOPSIS
    Resets the state of Windows Update on the current computer.
  .PARAMETER ComputerName
    The remote computer to reser Windows Update on. If this parameter is not
    provided, the job is run locally.
  .PARAMETER RebootNow
    Restart the computer immediately after restarting.
  .NOTES
    Based on this guide:

    https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-resources#reset-windows-update-components-manually
  #>
  [CmdletBinding()]
  param (
    [string] $ComputerName,
    [switch] $RebootNow
  )

  process {
    $resetOperation = {
      param (
        [switch] $RebootNow
      )
      Get-Service -Name 'bits', 'wuauserv' | Stop-Service -Force

      'Waiting 3 seconds to free file handles.' | Write-Verbose -Verbose
      Start-Sleep -Seconds 3

      $path = [System.IO.Path]::Combine(
        $env:ALLUSERSPROFILE,
        "\Application Data\Microsoft\Network\Downloader\"
      )
      Get-ChildItem -Path $path -Filter 'qmgr*.dat' | Remove-Item -Force

      @(
        'atl.dll'
        'urlmon.dll'
        'mshtml.dll'
        'shdocvw.dll'
        'browseui.dll'
        'jscript.dll'
        'vbscript.dll'
        'scrrun.dll'
        'msxml.dll'
        'msxml3.dll'
        'msxml6.dll'
        'actxprxy.dll'
        'softpub.dll'
        'wintrust.dll'
        'dssenh.dll'
        'rsaenh.dll'
        'gpkcsp.dll'
        'sccbase.dll'
        'slbcsp.dll'
        'cryptdlg.dll'
        'oleaut32.dll'
        'ole32.dll'
        'shell32.dll'
        'initpki.dll'
        'wuapi.dll'
        'wuaueng.dll'
        'wuaueng1.dll'
        'wucltui.dll'
        'wups.dll'
        'wups2.dll'
        'wuweb.dll'
        'qmgr.dll'
        'qmgrprxy.dll'
        'wucltux.dll'
        'muweb.dll'
        'wuwebv.dll'
      ) | ForEach-Object { & regsvr32.exe /s "$env:windir\System32\$_" }

      # This might be the command to fix the "PC is off" Windows Update error.
      & netsh.exe winsock reset

      Start-Service -Name 'bits', 'wuauserv'

      if ($RebootNow.IsPresent) {
        Restart-Computer -Force
      }
    }

    if ($PSBoundParameters.ContainsKey('ComputerName')) {
      $invokeCmdSplat = @{
        ComputerName = $ComputerName
        ScriptBlock = $resetOperation
        ArgumentList = $RebootNow.IsPresent
      }
      return Invoke-Command @invokeCmdSplat
    }

    $resetOperation.Invoke($RebootNow)
  }
}
