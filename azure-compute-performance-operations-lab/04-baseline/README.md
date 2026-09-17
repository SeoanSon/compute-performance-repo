# 04. 기준선 측정하기

## 목표

변경이나 장애를 주기 전 정상 상태의 성능을 수치로 고정합니다.

## 실행

```powershell
$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$artifacts = Join-Path $labRoot "artifacts"
$target = "http://$pip/api/orders"
$result = Join-Path $artifacts "load-tests\baseline-$runId.csv"

& (Join-Path $labRoot "scripts\http-baseline.ps1") `
  -TargetUrl $target `
  -DurationSeconds 60 `
  -Concurrency 8 `
  -OutputPath $result

Get-Content "$result.summary.json" | ConvertFrom-Json | Format-List
```

같은 명령을 두 번 실행합니다. 결과 파일을 삭제하지 않습니다.

## 통과 기준

- SuccessRate >= 99.5%
- P95Ms <= 250
- 두 실행의 p95 차이 <= 20%

## 기록

`baseline` 결과에서 RPS, p50, p95, 성공률, VMSS 인스턴스 수를 `artifacts/analysis.md`에 기록합니다.

## 다음 단계

[`../05-load-test/README.md`](../05-load-test/README.md)

