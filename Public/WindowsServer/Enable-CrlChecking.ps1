function Enable-CrlChecking {
  [CmdletBinding()]
  param (
    [string[]] $ComputerName
  )

  $enableCrl = {
    $splat = @{
      Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing\'
      Name = 'State'
      Value = 146432
    }
    Set-ItemProperty @splat
  }

  if ($PSBoundParameters.ContainsKey('ComputerName')) {
    return Invoke-Command -ComputerName $ComputerName -ScriptBlock $enableCrl
  }

  $enableCrl.Invoke()
}
