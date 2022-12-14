using namespace System.Collections.Generic

function ConvertTo-InvertedDictionary {
  <#
  .SYNOPSIS
    Given a hashtable of keys paired to arrays, invert the relationship to
    unique values and shared keys.
  .DESCRIPTION
    Given a hashtable of keys paired to arrays, invert the relationship to
    unique values and shared keys.
  .EXAMPLE
    PS C:\> $h = @{}
    PS C:\> $h.Add('qwer@meta.com', @('asdf', 'qwer', 'zxcv'))
    PS C:\> $h.Add('zxcv@meta.com', @('asdf', 'qwer', 'zxcv'))
    PS C:\> $h.Add('asdf@meta.com', @('asdf', 'qwer', 'zxcv'))
    PS C:\> ConvertTo-InvertedDictionary -InputHashtable $h

    Key  Value
    ---  -----
    asdf {qwer@meta.com, zxcv@meta.com, asdf@meta.com}
    qwer {qwer@meta.com, zxcv@meta.com, asdf@meta.com}
    zxcv {qwer@meta.com, zxcv@meta.com, asdf@meta.com}

    All of the common values in each array are instead mapped to the keys that
    owned the arrays that they were in.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNull()]
    [hashtable] $InputHashtable
  )

  begin {
    $definition = @'
using System;
using System.Collections.Generic;
using System.Linq;

namespace Utils;

public class DictionaryInverter
{
    public static Dictionary<TValue, List<TKey>> Invert<TKey, TValue>(
        Dictionary<TKey, TValue[]> dict
    )
        where TKey : notnull
        where TValue : notnull
    {
        if (dict == null)
            throw new ArgumentNullException(nameof(dict));
        return dict
            .SelectMany(pair => pair.Value.Select(val => new { Key = val, Value = pair.Key }))
            .GroupBy(item => item.Key)
            .ToDictionary(group => group.Key, group => group.Select(item => item.Value).ToList());
    }
}
'@
    if ($null -eq ('Utils.DictionaryInverter' -as [type])) {
      Add-Type -TypeDefinition $definition
    }
  }

  process {
    $dict = [Dictionary[object, object[]]]::new()
    foreach ($kvp in $InputHashtable.GetEnumerator()) {
      if ($null -ne $kvp.Value) {
        $dict.Add($kvp.Key, $kvp.Value)
      }
    }

    $method = [Utils.DictionaryInverter].GetMethod('Invert')
    $genericMethod = $method.MakeGenericMethod([object], [object])
    return $genericMethod.Invoke([Utils.DictionaryInverter], $dict)
  }
}
