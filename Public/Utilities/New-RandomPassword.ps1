using namespace System.Security.Cryptography

function New-RandomPassword {
  <#
  .SYNOPSIS
    Generate a psuedo-random password.
  .DESCRIPTION
    Generate a psuedo-random password with optional rules.
  .PARAMETER Length
    Length of the password, with a minimum of 20 characters.
  .PARAMETER NoNumbers
    Prevent the password from having numbers.
  .PARAMETER NoSymbols
    Prevent the password from having symbols.
  .EXAMPLE
    Get-RandomPassword

    Returns a string of pseudo-random characters 20 characters long.
  .NOTES
    The passwords are not cryptographically s ecure because of the use of Random.

    If a SecureString is returned, it is made read-only. Additionally, because
    the character set is accessed by reference, it's impossible to know which
    characters were added to the password if memory was accessed by an unknown
    party.

    The memory safety only applies to Windows machines, as .NET cannot encrypt
    SecureStrings on other operating systems.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(ValueFromPipeline)]
    [ValidateRange(20, 65536)]
    [int] $Length = 20,

    [switch] $NoNumbers,

    [switch] $NoSymbols,

    [switch] $Raw
  )

  begin {
    $lowerCase = 'abcdefghijklmnopqrstuvwxyz'.ToCharArray()
    $upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()

    $charSet = [System.Collections.Generic.List[char]]::new()
    $charSet.AddRange($lowerCase)
    $charSet.AddRange($upperCase)
    if (!$NoNumbers.IsPresent) {
      $numbers = '1234567890'.ToCharArray()
      $charSet.AddRange($numbers)
    }
    if (!$NoSymbols.IsPresent) {
      $symbols = '!@#$%^&*()-_+={}[];:''"<>,./?\|`~'.ToCharArray()
      $charSet.AddRange($symbols)
    }

    # This is a complicated way of checking for the following method:
    # [System.Security.Cryptography.RandomNumberGenerator]::GetInt32()
    # This method only exists in newer versions of .NET.
    $bindingFlags = @(
      [System.Reflection.BindingFlags]::Public
      [System.Reflection.BindingFlags]::Static
    )
    $rng = [System.Security.Cryptography.RandomNumberGenerator].GetMethod(
      'GetInt32', # Method that generates numbers.
      $bindingFlags, # Method is public and static.
      $null, # No binder needed.
      [System.Reflection.CallingConventions]::Any,
      ([int], [int]), # Parameters to that method.
      $null # There are no parameter options.
    )

    # If it is, then use it otherwise be sad.
    $typeName = 'System.Security.Cryptography.RandomNumberGenerator'
    $isCryptographicallySecure = $typeName -as [type] -and $null -ne $rng
    if (!$isCryptographicallySecure) {
      $random = [Random]::new()
    }
  }

  process {
    # If we can use GeneratePassword, we should.
    if (
      !$isCryptographicallySecure -and
      $null -ne ('System.Web.Security.Membership' -as [type])
    ) {
      if ($NoNumbers.IsPresent -and $NoSymbols.IsPresent) {
        $symbolRatio = 0
      } else {
        $symbolRatio = [math]::Floor($Length / 5)
      }

      $randomPassword =  [System.Web.Security.Membership]::GeneratePassword(
        $Length,
        $symbolRatio
      )

      if ($Raw.IsPresent) {
        return $randomPassword
      }

      $password = [System.Security.SecureString]::new()
      foreach ($char in $randomPassword.ToCharArray()) {
        $password.AppendChar($char)
      }
      $password.MakeReadOnly()
      return $password
    }

    if ($Raw.IsPresent) {
      $password = [System.Text.StringBuilder]::new()
      while ($password.Length -lt $Length) {
        if ($isCryptographicallySecure) {
          $randomIndex = [RandomNumberGenerator]::GetInt32(0, $charSet.Count)
        } else {
          $randomIndex = $random.Next(0, $charSet.Count)
        }
        $newCharacter = $charSet[$randomIndex]
        $null = $password.Append($newCharacter)
      }
      return $password.ToString()
    }

    $password = [System.Security.SecureString]::new()
    while ($password.Length -lt $Length) {
      if ($isCryptographicallySecure) {
        $randomIndex = [RandomNumberGenerator]::GetInt32(0, $charSet.Count)
      } else {
        $randomIndex = $random.Next(0, $charSet.Count)
      }
      $newCharacter = $charSet[$randomIndex]
      $password.AppendChar($newCharacter)
    }
    $password.MakeReadOnly()
    return $password
  }
}

<#
function New-RandomPassword {
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateRange(1, 128)]
    [int] $Length,

    [switch] $Raw
  )

  begin {
    $symbols = '!@#$%^&*()_-+=[{]};:>|./?'.ToCharArray()
  }

  process {
    $randomBytes = [byte[]]::new($Length)
    $charBuffer = [char[]]::new($Length)
    $count = 0

    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($randomBytes)

    for ($iter = 0; $iter -lt $Length; $iter++) {
      $i = [int]($randomBytes[$iter] % 87)
      # We must add the chars to numbers, otherwise the operator will convert
      # to strings.
      if ($i -lt 10) {
        $charBuffer[$iter] = [char]($i + [char]'0')
      } elseif ($i -lt 36) {
        $charBuffer[$iter] = [char]($i - 10 + [char]'A')
      } elseif ($i -lt 62) {
        $charBuffer[$iter] = [char]($i - 36 + [char]'a')
      } else {
        $charBuffer[$iter] = [char]($symbols[$i - 62])
        $count++
      }
    }

    if ($Raw.IsPresent) {
      return [string]::new($charBuffer)
    }

    $password = [System.Security.SecureString]::new()
    foreach ($char in $charBuffer) {
      $password.AppendChar($char)
    }
    $password.MakeReadOnly()
    return $password
  }
}
#>
