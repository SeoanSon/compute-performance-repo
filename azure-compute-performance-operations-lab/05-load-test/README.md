# 05. 부하 테스트하기

## 목표

HTTP 요청, CPU, 메모리, 디스크 부하를 독립적으로 실행해 병목 후보를 만듭니다.

## HTTP 부하

```powershell
$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$result = Join-Path $artifacts "load-tests\steady-$runId.csv"
& (Join-Path $labRoot "scripts\http-baseline.ps1") `
  -TargetUrl "http://$pip/api/orders" `
  -DurationSeconds 120 `
  -Concurrency 32 `
  -OutputPath $result
Get-Content "$result.summary.json" | ConvertFrom-Json | Format-List
```

## CPU 부하

```powershell
$cpu = "sudo apt-get update -y && sudo apt-get install -y stress-ng && stress-ng --cpu 4 --timeout 120s --metrics-brief"
az vmss run-command invoke -g $rg -n $vmss --instance-id 0 `
  --command-id RunShellScript --scripts $cpu
```

Flexible VMSS인 기존 환경은 `Install-WorkshopApi.ps1`의 Flexible 지원 경로를 사용하고, CPU 부하는 진행자에게 요청합니다.

## 통과 기준

- 테스트별 CSV와 summary JSON이 생성됨
- 같은 시간대의 VMSS 인스턴스 수와 부하 조건이 기록됨
- 기준선과 부하 결과를 비교할 수 있음

## 다음 단계

[`../06-analyze/README.md`](../06-analyze/README.md)

