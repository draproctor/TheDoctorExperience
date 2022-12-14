function Get-ObjectProvisioningError {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [System.Net.Mail.MailAddress] $ObjectId
  )

  process {
    try {
      $user = Get-AzureADUser -ObjectId $ObjectId
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }

    if ([string]::IsNullOrEmpty($user.ProvisioningErrors.ErrorDetail)) {
      return [PSCustomObject]@{
        ObjectId = $ObjectId
        ErrorCode = 'N/A'
        ErrorParameters = @()
        Errors = 'No errors!'
      }
    }

    $errorDetail = [xml]$user.ProvisioningErrors.ErrorDetail
    $provisioningErrors = $errorDetail.ServiceInstance.ObjectErrors.ErrorRecord

    $results = foreach ($record in $provisioningErrors) {
      [PSCustomObject]@{
        ObjectId = $ObjectId
        ErrorCode = $record.ErrorCode
        ErrorParameters = $record.ErrorParameters
        ErrorDescription = $record.ErrorDescription
      }
    }
    $results | Select-Object -Unique
  }
}
