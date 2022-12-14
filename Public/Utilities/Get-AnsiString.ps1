function Get-AnsiString {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [ValidateRange(0, 255)]
    [int] $Red,

    [Parameter(ValueFromPipeline)]
    [ValidateRange(0, 255)]
    [int] $Green,

    [Parameter(ValueFromPipeline)]
    [ValidateRange(0, 255)]
    [int] $Blue
  )

  process {
    # 38 = foreground color, 2 = something I don't understand
    "``e[38;2;${Red};${Green};${Blue}m"
  }
}
