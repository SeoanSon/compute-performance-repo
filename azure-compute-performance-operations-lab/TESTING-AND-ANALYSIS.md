# 테스트 및 결과 분석 가이드

## 1. 결과를 남기는 디렉터리

각 팀은 다음 구조로 결과를 저장합니다.

```text
artifacts/
  deployment-verification.txt
  baseline.csv
  load-tests/
    steady-01.txt
    cpu-01.txt
    disk-01.txt
  screenshots/
  analysis.md
  tuning-decision.md
  incident-timeline.md
```

모든 파일 이름에는 테스트 시각이나 run ID를 넣습니다. 예: `steady-20260917-1030.txt`.

## 2. 테스트 전에 기록할 값

```powershell
$runId = Get-Date -Format "yyyyMMdd-HHmm"
$target = "http://<LOAD_BALANCER_IP>"
$duration = 600

"runId=$runId`ntarget=$target`nduration=$duration`nstarted=$(Get-Date -Format o)" |
  Set-Content ".\artifacts\load-tests\run-$runId.txt"
```

반드시 함께 기록합니다.

- VMSS SKU와 인스턴스 수
- 디스크 tier와 caching
- 테스트 대상 URL
- 부하 생성기 위치
- 시작·종료 시각(UTC 권장)
- 변경 사항과 autoscale 정책

## 3. HTTP 기준선 테스트

부하 생성기는 별도 Linux VM, Cloud Shell, Azure Load Testing 중 하나를 사용합니다. 네트워크 경로가 달라지면 결과가 달라지므로 모든 비교 테스트에서 같은 부하 생성기를 사용합니다.

### `wrk` 예시

```bash
wrk -t4 -c32 -d10m --latency http://<LOAD_BALANCER_IP>/api/orders
```

### `hey` 예시

```bash
hey -z 10m -c 32 http://<LOAD_BALANCER_IP>/api/orders
```

출력에서 다음을 저장합니다.

- Requests/sec
- Average latency
- p50, p90, p95, p99
- Non-2xx responses
- Socket errors

### 단계형 부하

```bash
for c in 8 16 32 64; do
  echo "=== concurrency=$c ==="
  hey -z 5m -c "$c" http://<LOAD_BALANCER_IP>/api/orders
done | tee load-tests/concurrency-step.txt
```

각 단계 사이에 2분의 cool-down을 두고, VMSS 인스턴스 수와 autoscale 결정을 함께 기록합니다.

## 4. CPU·메모리·디스크 부하

테스트 대상 인스턴스에서만 수행합니다. 운영 리소스에는 실행하지 않습니다.

```bash
# CPU: 4개 worker를 10분 실행
stress-ng --cpu 4 --timeout 10m --metrics-brief

# 메모리: 가용 메모리의 약 60%를 사용
stress-ng --vm 1 --vm-bytes 60% --vm-keep --timeout 10m --metrics-brief

# 디스크: 테스트 전용 디렉터리에서만 실행
fio --name=randread --directory=/mnt/data --size=2G \
  --rw=randread --bs=16k --iodepth=32 --numjobs=2 \
  --runtime=600 --time_based --group_reporting
```

부하를 실행하는 동안 API 부하도 별도 생성해 애플리케이션 지표와 플랫폼 지표의 시간축을 겹칩니다.

## 5. 기준선 판정

기준선은 평균 하나가 아니라 정상 상태의 범위입니다.

| 지표 | 정상 예시 | 경고 예시 | 실패 예시 |
|---|---:|---:|---:|
| p95 latency | ≤250ms | 250~500ms | >500ms |
| 오류율 | ≤0.5% | 0.5~1% | >1% |
| CPU | 평균 ≤60% | 60~75% | >75% 10분 |
| 메모리 | ≤75% | 75~85% | >85% |
| 디스크 latency | 기준선의 ≤2배 | 2~4배 | >4배 |
| VMSS ready instances | 목표 수 | 목표-1 | 목표-2 이상 |

실제 서비스 특성에 따라 기준을 바꾸되, 테스트 시작 전에 고정합니다.

## 6. KQL 분석 쿼리

Log Analytics의 Logs에서 `<START>`와 `<END>`를 UTC 기준으로 바꿉니다.

### Heartbeat와 인스턴스 상태

```kusto
let startTime = datetime(<START>);
let endTime = datetime(<END>);
Heartbeat
| where TimeGenerated between (startTime .. endTime)
| summarize firstSeen=min(TimeGenerated), lastSeen=max(TimeGenerated),
            samples=count()
  by Computer
| order by Computer asc
```

### CPU·메모리·디스크 추세

```kusto
let startTime = datetime(<START>);
let endTime = datetime(<END>);
InsightsMetrics
| where TimeGenerated between (startTime .. endTime)
| where Namespace in ("Processor", "Memory", "LogicalDisk")
| summarize avg(Val), max(Val), percentile(Val, 95)
  by bin(TimeGenerated, 1m), Computer, Namespace, Name
| order by TimeGenerated asc
```

### 프로세스별 CPU

```kusto
Perf
| where TimeGenerated between (datetime(<START>) .. datetime(<END>))
| where ObjectName == "Process" and CounterName == "% Processor Time"
| summarize avg(CounterValue), max(CounterValue)
  by bin(TimeGenerated, 1m), Computer, InstanceName
| top 50 by avg_CounterValue desc
```

### 실패한 요청과 오류율

애플리케이션이 `AppRequests` 또는 `AppTraces`를 기록하도록 구성된 경우 사용합니다.

```kusto
AppRequests
| where TimeGenerated between (datetime(<START>) .. datetime(<END>))
| summarize
    requests=count(),
    failures=countif(Success == false),
    p50=percentile(DurationMs, 50),
    p95=percentile(DurationMs, 95),
    p99=percentile(DurationMs, 99)
  by bin(TimeGenerated, 1m), Name
| extend errorRate=100.0 * failures / requests
| order by TimeGenerated asc
```

### Activity Log에서 scale-out·배포 이벤트

```kusto
AzureActivity
| where TimeGenerated between (datetime(<START>) .. datetime(<END>))
| where ResourceProviderValue =~ "MICROSOFT.COMPUTE"
   or OperationNameValue has_any ("autoscale", "virtualMachineScaleSets")
| project TimeGenerated, OperationNameValue, ActivityStatusValue,
          ResourceGroup, ResourceId, Caller, Properties
| order by TimeGenerated asc
```

## 7. 병목 분석 방법

다음 순서로 결론을 만듭니다.

1. **영향 시각 확정**: p95 또는 오류율이 기준을 벗어난 첫 시각을 찾습니다.
2. **범위 확인**: 모든 인스턴스인지 특정 인스턴스인지 구분합니다.
3. **상관관계 확인**: CPU, 메모리, 디스크, 네트워크 중 같은 시각에 변한 지표를 찾습니다.
4. **반증 확인**: 높은 CPU가 있어도 p95가 변하지 않는 구간이 있는지 확인합니다.
5. **가설 검증**: 한 번에 한 가지 변경 또는 부하만 적용합니다.
6. **동일 조건 재실행**: 같은 duration, concurrency, endpoint로 비교합니다.

### 분석 예시

```text
관찰: 10:12부터 p95가 180ms에서 780ms로 상승
증거 1: 같은 시각 CPU p95가 82%에서 97%로 상승
증거 2: 디스크 latency와 네트워크는 정상 범위
증거 3: 인스턴스 2개 모두 같은 패턴
결론: CPU 포화가 1차 원인일 가능성이 높음
검증: 동일 부하에서 D2s_v5 -> D4s_v5 비교
판정: p95 780ms -> 320ms, 오류율 변화 없음
```

## 8. Autoscale 검증

스파이크 시작 시각, scale decision, 인스턴스 Ready 시각, SLO 회복 시각을 기록합니다.

```powershell
az vmss list-instances -g $rg -n $vmss `
  --query "[].{instance:instanceId,state:provisioningState}" -o table

az monitor autoscale show -g $rg -n "autoscale-$team" -o json
```

다음 값을 계산합니다.

```text
scale decision latency = scale decision time - threshold breach time
warm-up time = instance Ready time - provisioning start time
recovery time = SLO recovery time - threshold breach time
```

성공 기준 예시:

- 피크 시작 후 SLO 위반 시간이 5분 이하
- 새 인스턴스가 Ready 되기 전 트래픽에 포함되지 않음
- cool-down 뒤 정상 부하에서 2개 인스턴스로 복귀
- scale-in 중 오류율이 1% 미만

## 9. 튜닝 결과 분석

변경 전후를 반드시 같은 표로 비교합니다.

| 항목 | 변경 전 | 변경 후 | 변화율 | 판정 |
|---|---:|---:|---:|---|
| p95 latency |  |  |  |  |
| p99 latency |  |  |  |  |
| error rate |  |  |  |  |
| max CPU |  |  |  |  |
| disk latency |  |  |  |  |
| 평균 인스턴스 수 |  |  |  |  |
| 시간당 비용 |  |  |  |  |

다음 중 하나를 만족하고 안정성 저하가 없을 때 변경을 채택합니다.

- p95가 20% 이상 개선
- 동일 p95에서 비용 15% 이상 절감
- SLO 위반 시간이 50% 이상 감소

## 10. 장애 주입과 복구 검증

### Health Probe 실패

```bash
sudo systemctl stop order-api
# 관찰: backend health, HTTP 오류율, Activity Log
sudo systemctl start order-api
curl -f http://localhost/readyz
```

### CPU 포화

```bash
stress-ng --cpu 4 --timeout 10m --metrics-brief
```

복구를 선언하기 전에 p95, 오류율, CPU가 10분 동안 정상 범위인지 확인합니다.

### 장애 타임라인 필수 항목

- 탐지 시각과 탐지 방법
- 최초 영향 범위
- 처음 세운 가설
- 확인한 쿼리와 결과
- 완화 조치와 실행자
- 서비스 회복 시각
- 근본 원인과 반증
- 재발 방지 자동화

## 11. 정리와 결과 제출

```powershell
# 부하 생성기 종료 후 최종 상태 저장
az vmss list-instances -g $rg -n $vmss -o json |
  Set-Content .\artifacts\final-vmss-state.json

# 실습 종료 후 리소스 삭제
az group delete -n $rg --yes --no-wait
```

삭제 전에 `analysis.md`, `tuning-decision.md`, `incident-timeline.md`를 제출합니다.
