$ErrorActionPreference='Stop'
$base='http://127.0.0.1:8080'
function J($o){$o|ConvertTo-Json -Depth 10}
function Post($url,$body,$headers=@{}){Invoke-RestMethod $url -Method Post -ContentType 'application/json' -Headers $headers -Body (J $body)}
$a=Post "$base/api/v1/stores/bootstrap" @{storeName='Tenant A';storeType='RETAIL';businessTitle='Tenant A';adminName='Owner A';adminPin='1111';phone='';deviceId='TENANT-A-DEVICE';currency='IRR';platform='WINDOWS';deviceName='PC-A'}
$b=Post "$base/api/v1/stores/bootstrap" @{storeName='Tenant B';storeType='RETAIL';businessTitle='Tenant B';adminName='Owner B';adminPin='2222';phone='';deviceId='TENANT-B-DEVICE';currency='IRR';platform='WINDOWS';deviceName='PC-B'}
if($a.storeCode -eq $b.storeCode){throw 'Tenant codes collided'}
$la=Post "$base/api/v1/auth/login" @{storeCode=$a.storeCode;userId=[int]$a.userId;pin='1111';deviceId='TENANT-A-DEVICE';platform='WINDOWS';deviceName='PC-A'}
$lb=Post "$base/api/v1/auth/login" @{storeCode=$b.storeCode;userId=[int]$b.userId;pin='2222';deviceId='TENANT-B-DEVICE';platform='WINDOWS';deviceName='PC-B'}
$ha=@{Authorization="Bearer $($la.accessToken)"};$hb=@{Authorization="Bearer $($lb.accessToken)"}
$pa=Post "$base/api/v1/cloud-sync/push" @{items=@(@{entity='tenant_test';entityId='A';operation='UPSERT';payloadJson='{"tenant":"A"}';sourceVersion=1})} $ha
$pb=Post "$base/api/v1/cloud-sync/push" @{items=@(@{entity='tenant_test';entityId='B';operation='UPSERT';payloadJson='{"tenant":"B"}';sourceVersion=1})} $hb
$sa=Invoke-RestMethod "$base/api/v1/cloud-sync/snapshot" -Headers $ha
$sb=Invoke-RestMethod "$base/api/v1/cloud-sync/snapshot" -Headers $hb
if(-not ($sa.items | ? {$_.entityId -eq 'A'})){throw 'Tenant A missing its record'}
if($sa.items | ? {$_.entityId -eq 'B'}){throw 'Tenant A can see Tenant B data'}
if(-not ($sb.items | ? {$_.entityId -eq 'B'})){throw 'Tenant B missing its record'}
if($sb.items | ? {$_.entityId -eq 'A'}){throw 'Tenant B can see Tenant A data'}
Write-Host 'MULTI-TENANT ISOLATION PASSED'
