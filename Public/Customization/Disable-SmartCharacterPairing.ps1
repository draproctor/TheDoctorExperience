function Disable-SmartCharacterPairing {
  $keys = '(', ')', '[', ']', '{', '}', "'", '"'
  Remove-PSReadLineKeyHandler -Chord $keys
}
