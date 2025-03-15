& "$PSScriptRoot/Create-SecretHistoryGantt.ps1" -KeyVaultName kv-alek-test -SecretNames "SampleApp1-PrimaryKey","SampleApp1-SecondaryKey","SampleApp1-ActiveKey" -OutputMarkdownFile "SampleApp1.md"
& "$PSScriptRoot/Create-SecretHistoryGantt.ps1" -KeyVaultName kv-alek-test -SecretNames "SampleApp2-PrimaryKey","SampleApp2-SecondaryKey","SampleApp2-ActiveKey" -OutputMarkdownFile "SampleApp2.md"
& "$PSScriptRoot/Create-SecretHistoryGantt.ps1" -KeyVaultName kv-alek-test -SecretNames "SampleApp3-PrimaryKey","SampleApp3-SecondaryKey","SampleApp3-ActiveKey" -OutputMarkdownFile "SampleApp3.md"
& "$PSScriptRoot/Create-SecretHistoryGantt.ps1" -KeyVaultName kv-alek-test -SecretNames "SampleApp4-PrimaryKey","SampleApp4-SecondaryKey","SampleApp4-ActiveKey" -OutputMarkdownFile "SampleApp4.md"
