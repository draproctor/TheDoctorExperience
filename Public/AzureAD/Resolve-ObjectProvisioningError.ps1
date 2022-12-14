function Resolve-ObjectProvisioningError {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipelineByPropertyName = $true)]
    [System.Net.Mail.MailAddress] $ObjectId
  )

  begin {
    $pattern = '[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}'
    $errorCase1 = (
      'Failed to enable the new cloud archive {0} of mailbox {0} because ' +
      'a different archive ({0}) exists. To enable the new archive, first ' +
      'disable the archive on-premises. After the next Dirsync sync cycle, ' +
      'enable the archive on-premises again.'
    ) -f $pattern -as [regex]
    $errorCase2 = (
      'The value "({0})" of property "ArchiveGuid" is used by another ' +
      'recipient object. Please specify a unique value.'
    ) -f $pattern -as [regex]
    # Error Case 3 seems to happen with disabled users.
    $errorCase3 = (
      'Failed to sync the ArchiveGuid {0} of mailbox {0} because one cloud ' +
      'archive ({0}) exists.'
    ) -f $pattern -as [regex]
  }

  process {
    $provisioningErrors = $ObjectId | Get-ObjectProvisioningError

    if ($provisioningErrors.ErrorCode -eq 'N/A') {
      return $provisioningErrors
    }

    if ($provisioningErrors.ErrorDescription -match $errorCase2) {
      $unusedGuid = [guid]::Empty.Guid
      # Didn't think I'd need to check for an unused GUID, but here we are...
      do {
        $newGuid = [guid]::NewGuid().Guid
        $mailbox = Get-RemoteMailbox -Filter "ArchiveGuid -eq '$newGuid'"
        if ($null -eq $mailbox) {
          $unusedGuid = $newGuid
        }
      } until ($unusedGuid -ne [guid]::Empty.Guid)
      Set-RemoteMailbox -Identity $ObjectId.Address -ArchiveGuid $unusedGuid
      return
    }

    switch ($provisioningErrors.ErrorCode) {
      'ExA77C31' {
        $results = $errorCase1.Matches($provisioningErrors.ErrorDescription)
        $archiveGuid = $results.Groups[1].Value
        Set-RemoteMailbox -Identity $ObjectId.Address -ArchiveGuid $archiveGuid
      }
      'Ex036831' {
        "$($ObjectId.Address) is a disabled user." | Write-Warning
      }
      'Ex9ABFAD' {
        "$($ObjectId.Address) is a disabled user." | Write-Warning
      }
      default {
        "Unknown error code: $($provisioningErrors.ErrorCode)" |
          Write-Verbose -Verbose
      }
    }
  }
}
