filter RemoveAllGroupMembersEntries {
  if ($_.EffectiveUserName -ne 'All Group Members') { $_ }
}

function Get-ManagementRoleEntryUser {
  param (
    [Parameter(Mandatory)]
    [string] $CmdletName,

    [ValidateSet('Minimal', 'Default', 'Full')]
    [string] $SummaryType = 'Default'
  )

  $roles = @(Get-ManagementRole -Cmdlet $CmdletName | Sort-Object Name)
  $count = 0

  @(
    "Found $($roles.Count) roles matching cmdlet '$CmdletName'. "
    "Enumerating members..."
  ) -join [string]::Empty | Write-Verbose -Verbose

  $assignments = foreach ($role in $roles) {
    $count++
    $pctcomplete = ($count / $roles.Count) * 100
    $spWriteProgress = @{
      Activity = "Enumerating Cmdlet=$CmdletName RoleName=$($role.Name)"
      Status = "$count/$($roles.Count) roles enumerated"
      PercentComplete = $pctcomplete
    }
    Write-Progress @spWriteProgress
    Get-ManagementRoleAssignment -Role $role.Name -GetEffectiveUsers |
      RemoveAllGroupMembersEntries
  }

  switch ($SummaryType) {
    'Minimal' {
      $assignments | Select-Object -Property 'EffectiveUserName' -Unique
    }
    'Default' {
      $defaultProps = @(
        'Count'
        @{
          n = 'EffectiveUserName'
          e = { $_.Name }
        }
        @{
          n = 'RoleEntries'
          e = { $_.Group.Name }
        }
      )
      $assignments |
        Group-Object -Property 'EffectiveUserName' |
        Sort-Object -Property 'Count' -Descending |
        Select-Object -Property $defaultProps
    }
    'Full' { $assignments }
  }
}
