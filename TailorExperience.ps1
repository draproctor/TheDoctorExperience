using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# ISE hates the Doctor Experience. Do nothing.
if ($Host.Name -eq 'Windows PowerShell ISE Host') {
  return
}

# Works in both PowerShell 5.1 and Pwsh 7!
if ($IsWindows -and $PSVersionTable.PSVersion.Major -eq 7) {
  Import-Module -Name 'WindowsCompatibility' -WarningAction 'SilentlyContinue'
  # -SkipEditionCheck throws a PSSnapIn error.
  Import-Module -Name 'ActiveDirectory' -WarningAction 'SilentlyContinue'
}

if ($PSVersionTable.PSVersion.Major -eq 5) {
  Import-Module -Name 'AzureAD' -ErrorAction 'Continue'
}

if (!$IsMacOS) {
  Import-Module -Name 'FbitMessaging' -ErrorAction 'Continue'
}

if ((Get-Module -Name 'PSReadline').Version -le '2.1') {
  Remove-Module -Name 'PSReadline'
  Import-Module -Name 'PSReadLine' -MinimumVersion '2.1.0'
}

Import-Module -Name 'ExchangeOnlineManagement' -ErrorAction 'Continue'

if ($PSVersionTable.PSVersion -gt '7.1') {
  $PSStyle.Formatting.FormatAccent = "`e[38;2;221;187;136m"
  $PSStyle.Formatting.TableHeader = "`e[38;2;221;187;136m"
}

Set-PSReadLineOption -PredictionSource 'History'
# Set-PSReadLineOption -ContinuationPrompt '∙'

$quotePairingSplat = @{
  Key = '"', "'"
  BriefDescription = 'SmartInsertQuote'
  LongDescription = 'Insert paired quotes if not already on a quote'
  ScriptBlock = {
    param($key, $arg)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState(
      [ref] $selectionStart,
      [ref] $selectionLength
    )

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
      [ref] $line,
      [ref] $cursor
    )

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
        $selectionStart,
        $selectionLength,
        $quote + $line.SubString($selectionStart, $selectionLength) + $quote
      )
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(
        $selectionStart + $selectionLength + 2
      )
      return
    }

    $ast = $null
    $tokens = $null
    $parseErrors = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
      [ref] $ast,
      [ref] $tokens,
      [ref] $parseErrors,
      [ref] $null
    )

    function Find-Token {
      param($Tokens, $Cursor)

      foreach ($token in $Tokens) {
        if ($Cursor -lt $token.Extent.StartOffset) { continue }
        if ($Cursor -lt $token.Extent.EndOffset) {
          $result = $token
          $token = $token -as [StringExpandableToken]
          if ($token) {
            $nested = Find-Token -Tokens $token.NestedTokens -Cursor $Cursor
            if ($nested) { $result = $nested }
          }

          return $result
        }
      }
      return $null
    }

    $token = Find-Token -Tokens $tokens -Cursor $cursor

    # If we're on or inside a **quoted** string token, we need to be smarter
    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
      # If we're at the start of the string, assume we're inserting a new string
      if ($token.Extent.StartOffset -eq $cursor) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        return
      }

      # If we're at the end of the string, move over the closing quote if present.
      if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        return
      }
    }

    if (
      $null -eq $token -or
      $token.Kind -eq [TokenKind]::RParen -or
      $token.Kind -eq [TokenKind]::RCurly -or
      $token.Kind -eq [TokenKind]::RBracket
    ) {
      if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
        # Odd number of quotes before the cursor, insert a single quote
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
      } else {
        # Insert matching quotes, move cursor to be in between the quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
      }
      return
    }

    # If cursor is at the start of a token, enclose it in quotes.
    if ($token.Extent.StartOffset -eq $cursor) {
      if (
        $token.Kind -eq [TokenKind]::Generic -or
        $token.Kind -eq [TokenKind]::Identifier -or
        $token.Kind -eq [TokenKind]::Variable -or
        $token.TokenFlags.hasFlag([TokenFlags]::Keyword)
      ) {
        $end = $token.Extent.EndOffset
        $len = $end - $cursor
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
          $cursor,
          $len,
          $quote + $line.SubString($cursor, $len) + $quote
        )
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
        return
      }
    }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
  }
}
Set-PSReadLineKeyHandler @quotePairingSplat

$smartBackspaceSplat = @{
  Key = 'Backspace'
  BriefDescription = 'SmartBackspace'
  LongDescription = 'Delete previous character or matching quotes/parens/braces'
  ScriptBlock = {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
      [ref] $line,
      [ref] $cursor
    )

    if ($cursor -gt 0) {
      $toMatch = $null
      if ($cursor -lt $line.Length) {
        switch ($line[$cursor]) {
          '"' { $toMatch = '"'; break }
          "'" { $toMatch = "'"; break }
          ')' { $toMatch = '('; break }
          ']' { $toMatch = '['; break }
          '}' { $toMatch = '{'; break }
        }
      }

      if ($null -ne $toMatch -and $line[$cursor - 1] -eq $toMatch) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
      } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
      }
    }
  }
}
Set-PSReadLineKeyHandler @smartBackspaceSplat

# Pasting in VSCode enters one char at a time, breaking multiline pastes.
if ($env:TERM_PROGRAM -ne 'vscode') {
  $insertPairedBraces = @{
    Key = '(', '{', '['
    BriefDescription = 'InsertPairedBraces'
    LongDescription = 'Insert matching braces'
    ScriptBlock = {
      param($key, $arg)

      $closeChar = switch ($key.KeyChar) {
        '(' { [char]')'; break }
        '{' { [char]'}'; break }
        '[' { [char]']'; break }
      }

      $selectionStart = $null
      $selectionLength = $null
      [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState(
        [ref] $selectionStart,
        [ref] $selectionLength
      )

      $line = $null
      $cursor = $null
      [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
        [ref] $line,
        [ref] $cursor
      )

      if ($selectionStart -ne -1) {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
          $selectionStart,
          $selectionLength,
          $key.KeyChar +
          $line.SubString($selectionStart, $selectionLength) +
          $closeChar
        )
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition(
          $selectionStart + $selectionLength + 2
        )
      } else {
        # No text is selected, insert a pair
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
      }
    }
  }
  Set-PSReadLineKeyHandler @insertPairedBraces

  $smartCloseBracesSplat = @{
    Key = ')', ']', '}'
    BriefDescription = 'SmartCloseBraces'
    LongDescription = 'Insert closing brace or skip'
    ScriptBlock = {
      param($key, $arg)

      $line = $null
      $cursor = $null
      [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState(
        [ref] $line,
        [ref] $cursor
      )

      if ($line[$cursor] -eq $key.KeyChar) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
      } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
      }
    }
  }
  Set-PSReadLineKeyHandler @smartCloseBracesSplat
}

# Colors are garish without Windows Terminal or iTerm2.
if ($env:TERM_PROGRAM -eq 'iTerm.app' -or $env:WT_SESSION) {
  Set-PSReadLineOption -Colors @{
    Command = '#3398db' # Blue
    Keyword = '#c9a022' # Orange
    Member = '#ddbb88' # Tan
    Number = '#d26d32' # Orange
    Parameter = '#a4a4a4' # Gray
    String = '#36ae70' # Green
    Variable = '#de456b' # Red-ish
    Type = '#935cd1' # Purple
  }
}

if ($null -eq $env:STARSHIP_SHELL) {
  function global:prompt {
    $dir = $PWD.Path
    # Replace home directory with a tilde.
    if ($HOME -ne '' -and $dir.ToLower().StartsWith($HOME.ToLower())) {
      $dir = $dir.Replace($HOME, '~')
    }

    $user = $env:USERNAME
    if ($PSVersionTable.PSVersion.Major -gt 6 -and $IsMacOS) {
      $user = $env:USER
    }

    $colors = @(
      [Tuple]::Create($user, 'Magenta')
      [Tuple]::Create('@', 'Cyan')
      [Tuple]::Create([Environment]::MachineName, 'Yellow')
      [Tuple]::Create('^', 'Red')
      [Tuple]::Create([datetime]::Now.ToString('t'), 'Cyan')
      [Tuple]::Create(':', 'Red')
      # The new line moves the prompt to the very left,
      # providing more screen space for cmdlets.
      [Tuple]::Create("$dir`n", 'Cyan')
      [Tuple]::Create('|', 'Red')
      [Tuple]::Create('-> ', 'Cyan')
    )

    foreach ($textColor in $colors) {
      Write-Host -Object $textColor.Item1 -ForegroundColor $textColor.Item2 -NoNewline
    }
    # PowerShell leaves an extra ">" at the prompt. GTFO.
    return "`b "
  }
} else {
  Invoke-Expression -Command (& starship init powershell)
}

@'
| ____    __    ____  _______  __        ______   ______   .___  ___.  _______    .______        ___        ______  __  ___      |
| \   \  /  \  /   / |   ____||  |      /      | /  __  \  |   \/   | |   ____|   |   _  \      /   \      /      ||  |/  /      |
|  \   \/    \/   /  |  |__   |  |     |  ,----'|  |  |  | |  \  /  | |  |__      |  |_)  |    /  ^  \    |  ,----'|  '  /       |
|   \            /   |   __|  |  |     |  |     |  |  |  | |  |\/|  | |   __|     |   _  <    /  /_\  \   |  |     |    <        |
|    \    /\    /    |  |____ |  `----.|  `----.|  `--'  | |  |  |  | |  |____    |  |_)  |  /  _____  \  |  `----.|  .  \   __  |
|     \__/  \__/     |_______||_______| \______| \______/  |__|  |__| |_______|   |______/  /__/     \__\  \______||__|\__\ (_ ) |
|                             _______    ______     ______ .___________.  ______   .______                                   |/  |
|                            |       \  /  __  \   /      ||           | /  __  \  |   _  \                                      |
|                            |  .--.  ||  |  |  | |  ,----'`---|  |----`|  |  |  | |  |_)  |                                     |
|                            |  |  |  ||  |  |  | |  |         |  |     |  |  |  | |      /                                      |
|                            |  '--'  ||  `--'  | |  `----.    |  |     |  `--'  | |  |\  \----.                                 |
|                            |_______/  \______/   \______|    |__|      \______/  | _| `._____|                                 |

'@ | Write-Host -ForegroundColor 'White' -BackgroundColor 'DarkCyan'

# If pwsh is opened on a UNC path, let's move back to the home directory.
if ((Get-Location).Path.StartsWith('//')) {
  Set-Location -Path $HOME
}
