param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$scriptPath = Join-Path $PSScriptRoot "load_test_recsys.js"
node $scriptPath @Args
exit $LASTEXITCODE

