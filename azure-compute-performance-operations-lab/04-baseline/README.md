# 04. 기준선 측정하기

## 목표

변경이나 장애를 주기 전 정상 상태의 성능을 수치로 고정합니다.

## 이 단계에서 배우는 것

- “빠르다/느리다” 대신 latency percentile을 사용하는 이유
- 평균값보다 p95·p99가 사용자 경험과 SLO에 가까운 이유
- 성능 실험에서 부하 조건·측정 시간·인스턴스 수를 고정해야 하는 이유

## 핵심 지표

| 지표 | 의미 |
|---|---|
| `RequestsPerSecond` | 처리량 |
| `P50Ms` | 일반적인 요청의 체감 |
| `P95Ms` | 느린 요청의 tail 성능 |
| `SuccessRate` | 사용자 요청 성공 여부 |
| 인스턴스 수 | 성능과 비용의 기반 |

## 스스로 답할 질문

- p50은 정상인데 p95만 나빠지면 어떤 사용자가 영향을 받는가?
- 기준선 테스트를 두 번 반복해야 하는 이유는 무엇인가?
- 기준선이 없으면 튜닝 효과를 어떻게 증명하기 어려운가?

## 실행

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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
