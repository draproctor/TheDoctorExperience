function Disable-CrlChecking {
  [CmdletBinding()]
  param (
    [string[]] $ComputerName
  )

  $disableCrl = {
    $splat = @{
      Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\'
      Name = 'State'
      Value = 146944
    }
    Set-ItemProperty @splat
  }

  if ($PSBoundParameters.ContainsKey('ComputerName')) {
    return Invoke-Command -ComputerName $ComputerName -ScriptBlock $disableCrl
  }

  $disableCrl.Invoke()
}
