function Enable-SmartCharacterPairing {
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
