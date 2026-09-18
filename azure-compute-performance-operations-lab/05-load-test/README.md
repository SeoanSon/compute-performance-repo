# 05. 부하 테스트하기

## 목표

HTTP 요청, CPU, 메모리, 디스크 부하를 독립적으로 실행해 병목 후보를 만듭니다.

## 이 단계에서 배우는 것

- 부하를 한꺼번에 섞지 않고 한 가지씩 주는 실험 설계
- 처리량을 높이는 것과 latency·오류율을 지키는 것의 차이
- CPU, 메모리, 디스크 부하가 서로 다른 증상과 지표를 만든다는 점
- 재현 가능한 부하 프로파일을 운영 테스트로 승격하는 방법

## 실험 흐름

```text
Warm-up → Steady load → Resource stress → Cool-down
                         ↓
                 API 지표 + VM 지표 기록
```

## 관찰 포인트

- CPU가 상승할 때 p95와 오류율도 같은 시각에 상승하는가?
- 메모리 압박이 paging 또는 응답 지연으로 이어지는가?
- 디스크 latency가 IOPS·throughput·queue와 함께 변하는가?
- 부하를 멈춘 뒤 정상 상태로 돌아오는 데 얼마나 걸리는가?

## HTTP 부하

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

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
