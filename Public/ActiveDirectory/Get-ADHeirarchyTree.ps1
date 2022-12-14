class Employee {
  [string] $Manager
  [System.Collections.Generic.List[Employee]] $DirectReports

  Employee([string] $manager) {
    $this.Manager = $manager
    $this.DirectReports = [System.Collections.Generic.List[Employee]]::new()

    $getReports = @{
      Identity = $manager
      Properties = 'directReports'
      ErrorAction = 'Stop'
    }
    try {
      # Using LINQ is faster than using Where-Object and we also don't depend
      # on a filter function. To make LINQ work, we have to strongly type our
      # collections.
      $reports = [string[]](Get-ADUser @getReports).directReports
      $filter = [Func[string, bool]]{ return $_ -notlike '*DisabledUser*' }
      $directs = [System.Linq.Enumerable]::ToList(
        [System.Linq.Enumerable]::Where(
          [System.Collections.Generic.List[string]]$reports,
          $filter
        )
      )
      if ($directs.Count -eq 0) {
        return
      }
    } catch {
      return
    }
    foreach ($report in $directs) {
      $this.DirectReports.Add([Employee]::new($report))
    }
  }
}

function Get-ADHeirarchyTree {
  [CmdletBinding()]
  param (
    [string] $TopLevelManager
  )

  process {
    $dn = (Get-ADUser -Identity $TopLevelManager).DistinguishedName
    return [Employee]::new($dn)
  }
}
