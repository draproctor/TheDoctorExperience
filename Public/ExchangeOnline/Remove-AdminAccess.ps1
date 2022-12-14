function Remove-AdminAccess {
  [Alias('raa')]
  Param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [String]$Identity,

    [Parameter(Position = 1)]
    [String]$User = $env:username
  )

  process {
    $raaSplat = @{
      AccessRights = 'FullAccess'
      Identity = $Identity
      User = $User
      InheritanceType = 'All'
      Confirm = $False
    }
    Remove-MailboxPermission @raaSplat
  }
}
