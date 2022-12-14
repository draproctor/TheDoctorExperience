function Get-DexMailboxFolderIdQuery {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Identity,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $FolderName,

    [switch] $QueryOnly
  )

  process {
    $encoding = [System.Text.Encoding]::GetEncoding('us-ascii')
    $folderStatistics = Get-MailboxFolderStatistics -Identity $Identity |
      Where-Object { $_.FolderPath -like "*$FolderName*" }

    # What is this arcane black magic?
    foreach ($folderStatistic in $folderStatistics) {
      $folderId = $folderStatistic.FolderId
      $folderPath = $folderStatistic.FolderPath
      $folderIdBytes = [Convert]::FromBase64String($folderId)

      $nibbler = $encoding.GetBytes('0123456789ABCDEF')
      $indexIdIdx = 0
      $indexIdBytes = [byte[]]::new(48)

      $folderIdBytes |
        Select-Object -Skip 23 -First 24 |
        ForEach-Object {
          $indexIdBytes[$indexIdIdx++] = $nibbler[$_ -shr 4]
          $indexIdBytes[$indexIdIdx++] = $nibbler[$_ -band 0xF]
        }
      $folderId = $encoding.GetString($indexIdBytes)
      $folderQuery = "folderid:$folderId"

      if ($QueryOnly.IsPresent) {
        $folderQuery
        continue
      }

      [PSCustomObject]@{
        Name = $Identity
        FolderPath = $folderPath
        FolderId = $folderId
        FolderQuery = $folderQuery
      }
    }
  }
}
