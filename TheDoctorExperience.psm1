using namespace Microsoft.Online.Administration.Automation
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Management.Automation.Runspaces
using namespace System.Net
using namespace System.Security.Cryptography
using namespace System.Security.Principal
using namespace System.Text
using namespace System.Timers

class ValidateFileExistsAttribute : ValidateArgumentsAttribute {
  [void] Validate([object] $path, [EngineIntrinsics] $instrinsics) {
    if ([string]::IsNullOrEmpty($path)) {
      throw [System.ArgumentNullException]::new('path')
    }

    $path = [System.IO.Path]::GetFullPath($path)

    if ([System.IO.Directory]::Exists($path)) {
      throw [System.IO.FileNotFoundException]::new(
        "$path is a directory, not a file.",
        $path
      )
    }

    if (![System.IO.File]::Exists($path)) {
      throw [System.IO.FileNotFoundException]::new()
    }
  }
}

class AdminAccess {
  [string] $User
  [string] $Admin
  [string] $MailboxUri
  [string] $CalendarUri
}

class DexJobTracker {
  hidden static [Dictionary[string, Timer]] $ActiveJobs =
    [Dictionary[string, Timer]]::new()

  static [string] GetJob([string] $job) {
    if ([DexJobTracker]::ActiveJobs.ContainsKey($job)) {
      return $job
    }
    return [guid]::Empty.Guid
  }

  static [void] AddJob([string] $job, [Timer] $timer) {
    # We need to keep a reference to the Timer
    # to ensure the events actually trigger.
    [DexJobTracker]::ActiveJobs.Add($job, $timer)
  }

  static [void] RemoveJob([string] $job) {
    [DexJobTracker]::ActiveJobs.Remove($job)
  }
}

class DexServiceStatus {
  [string] $UserPrincipalName
  [psobject[]] $Services
}

#region Mailbox Control
class CalendarPermission {
  [string] $Calendar
  [string] $User
  [string] $AccessRights
  [bool] $NotificationsEnabled
  [bool] $IsNewAccess

  [void] RemovePermission() {
    $splat = @{
      Identity = $this.Calendar + ':\Calendar'
      User = $this.User
      Confirm = $false
    }
    Remove-MailboxFolderPermission @splat
  }
}
#endregion

#region Object Control
function ConvertTo-SnakeCaseKey {
  <#
  .SYNOPSIS
    Converts hashtables to hashtables with snake_case keys.
  #>
  [CmdletBinding()]
  [OutputType([hashtable])]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [hashtable]$InputHashtable
  )

  process {
    $clone = $InputHashtable.Clone()
    $newHash = @{}

    foreach ($kv in $clone.GetEnumerator()) {
      $key = $kv.Key | ConvertTo-SnakeCaseString
      $newHash.Add($key, $kv.Value)
    }

    return $newHash
  }
}

function ConvertTo-List {
  [CmdletBinding()]
  [OutputType([System.Collections.Generic.List[object]])]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$InputObject
  )

  begin {
    $list = [System.Collections.Generic.List[object]]::new()
  }

  process {
    $list.Add($InputObject)
  }

  end {
    # This method allows us to not enumerate the object.
    $PSCmdlet.WriteObject($list, $false)
  }
}
#endregion

#region Office 365 Control
function Get-DexExchangeLicenseStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [System.Net.Mail.MailAddress]$Identity
  )

  process {
    try {
      $splat = @{
        UserPrincipalName = $Identity.Address
        ErrorAction = 'Stop'
      }
      $user = Get-MsolUser @splat
    } catch [Microsoft.Online.Administration.Automation.MicrosoftOnlineException] {
      Connect-MsolService
    }

    $license = $user.Licenses.ServiceStatus |
      Where-Object { $_.ServicePlan.ServiceName -like '*exchange*' }

    [DexServiceStatus]@{
      UserPrincipalName = $Identity.Address
      Services = $license
    }
  }
}

function Get-AdminConsentUrl {
  [CmdletBinding()]
  param (
    [string]$ClientID,
    [string]$TenantId
  )

  process {
    'https://login.microsoftonline.com/{0}/adminconsent?client_id={1}' -f @(
      $TenantId
      $ClientID
    )
  }
}
#endregion

function Get-ExchangeServerPatch {
  [CmdletBinding()]
  param (
    [string] $HotFixId
  )

  $servers = Get-ExchangeServer
  $grouping = @{ }

  foreach ($s in $servers) {
    $hotfix = Invoke-Command -AsJob -ComputerName $s.Fqdn -ScriptBlock {
      $hotFixId = $using:HotFixId
      $splat = @{
        ClassName = 'Win32_QuickFixEngineering'
        Filter = "HotFixId = '$hotFixId'"
      }
      Get-CimInstance @splat
    }
    $grouping[$s] = $hotfix
  }

  $grouping.Values | Wait-Job | Out-Null

  foreach ($kv in $grouping.Clone().GetEnumerator()) {
    $grouping[$kv.Key] = $kv.Value | Receive-Job
  }

  return $grouping
}

function Get-MailboxInstanceStatistics {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [string]$Identity
  )

  process {
    $mbx = Get-EXOMailbox -Identity $Identity -Properties 'MailboxLocations'
    $mbx.MailboxLocations |
      ForEach-Object { $_.Split(';')[1] } |
      Get-EXOMailboxStatistics
  }
}

function Get-DexMessageTrace {
  [CmdletBinding()]
  param (
    [string] $SenderAddress,

    [string] $RecipientAddress,

    [string] $MessageId,

    [string] $MessageTraceId,

    [datetime] $StartDate = [datetime]::Now.AddDays(-10),

    [datetime] $EndDate = [datetime]::Now
  )

  process {
    $splat = @{
      StartDate = $StartDate
      EndDate = $EndDate
    }

    $parameters = @(
      'SenderAddress'
      'RecipientAddress'
      'MessageId'
      'MessageTraceId'
      'StartDate'
      'EndDate'
    )
    foreach ($parameter in $parameters) {
      if ($PSBoundParameters.ContainsKey($parameter)) {
        $splat[$parameter] = Get-Variable -Name $parameter -ValueOnly
      }
    }

    Get-MessageTrace @splat
  }
}

function Resolve-ObjectProvisioningError {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipelineByPropertyName)]
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

function New-DexScheduledJob {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { $_ -ne [guid]::Empty.Guid })]
    [string] $Name,

    [Parameter(Mandatory)]
    [timespan] $Interval,

    [Parameter(Mandatory)]
    [scriptblock] $ScriptBlock,

    [switch] $AutoReset
  )

  process {
    $timer = [System.Timers.Timer]::new()
    $timer.Interval = $Interval.TotalMilliseconds
    $timer.Enabled = $true
    $timer.AutoReset = $AutoReset.IsPresent

    $timerEvent = @{
      InputObject = $timer
      SourceIdentifier = $Name
      EventName = 'Elapsed'
      Action = $ScriptBlock
    }
    try {
      Register-ObjectEvent @timerEvent
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }

    [DexJobTracker]::AddJob($Name, $timer)
  }
}

function Get-DexScheduledJob {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
  )

  process {
    try {
      $job = [DexJobTracker]::GetJob($Name)
      if ($job -eq [guid]::Empty.Guid) {
        throw "The job '$Name' doesn't exist!"
      }

      Get-EventSubscriber -SourceIdentifier $job
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
}

function Remove-DexScheduledJob {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
  )

  process {
    try {
      $job = [DexJobTracker]::GetJob($Name)
      if ($job -eq [guid]::Empty.Guid) {
        throw "The job '$Name' doesn't exist!"
      }

      Unregister-Event -SourceIdentifier $job
      [DexJobTracker]::RemoveJob($job)
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
}

$commands = @(
  'Get-DexScheduledJob'
  'Remove-DexScheduledJob'
)
foreach ($commandName in $commands) {
  $getDexScheduledJobCompleterSplat = @{
    CommandName = $commandName
    ParameterName = 'Name'
    ScriptBlock = {
      param (
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
      )

      return [DexJobTracker]::ActiveJobs |
        Where-Object { $_ -like "*$WordToComplete*" } |
        Sort-Object |
        ForEach-Object { [CompletionResult]::new($_) }
    }
  }
  Register-ArgumentCompleter @getDexScheduledJobCompleterSplat
}

$public = @(
  Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -Recurse -ErrorAction 'Stop'
)
foreach ($import in @($public)) {
  try {
    . $import.FullName
  } catch {
    throw "Unable to dot source [$($import.FullName)]"
  }
}

$functions = @(
  $public.Basename
  'ConvertTo-List'
  'Copy-DexLocalModule'
  'Get-AdminConsentUrl'
  'Get-ExchangeServerPatch'
  'Get-MailboxInstanceStatistics'
)

Export-ModuleMember -Function $functions -Alias '*'
