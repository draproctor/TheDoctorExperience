function Add-AdminAccess {
  [Alias('aaa')]
  Param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [System.Net.Mail.MailAddress]$Identity,

    [Parameter(Position = 1)]
    [String]$User = $env:username
  )

  process {
    $aaaSplat = @{
      Identity = $Identity.Address
      AccessRights = 'FullAccess'
      User = $User
      InheritanceType = 'All'
      AutoMapping = $false
    }
    $null = Add-MailboxPermission @aaaSplat

    # This totally isn't confusing :P
    [AdminAccess]@{
      User = $Identity
      Admin = $User
      MailboxUri = "https://outlook.office.com/mail/$Identity"
      CalendarUri = "https://outlook.office.com/calendar/$Identity/view/month"
    }
  }
}
