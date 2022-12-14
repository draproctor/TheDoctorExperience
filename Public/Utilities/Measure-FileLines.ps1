function Measure-FileLines {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateFileExists()]
    [string] $Path
  )

  process {
    # https://www.nimaara.com/counting-lines-of-a-text-file/
    $absolutePath = (Resolve-Path -Path $Path).Path
    ([System.IO.File]::ReadLines($absolutePath) | Measure-Object).Count
  }
}
