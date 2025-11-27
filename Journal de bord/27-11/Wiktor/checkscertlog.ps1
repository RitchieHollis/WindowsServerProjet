$ids = 4886, 4887, 4888, 4889, 4890, 4891, 4892, 4893
Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = $ids
    StartTime = (Get-Date).AddHours(-1)
} | Select-Object -First 15 TimeCreated, Id, ProviderName, Message
