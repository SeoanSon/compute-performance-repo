# 06. 분석하기

## 목표

사용자 영향과 Azure 플랫폼 지표를 같은 시간축에서 비교해 병목 원인을 설명합니다.

## 이 단계에서 배우는 것

- KQL로 heartbeat·CPU·메모리·디스크 시계열을 조회하는 방법
- 사용자 지표와 플랫폼 지표를 같은 시간축에 놓는 방법
- 단일 높은 지표가 아니라 원인 가설·상관관계·반증으로 결론을 만드는 방법

## 분석 프레임

```text
증상 확인 → 영향 시각 확정 → 범위 확인 → 상관 지표 탐색
        → 반증 확인 → 가설 검증 → 결론과 다음 조치
```

## 좋은 결론의 형태

> “10:12부터 p95가 상승했고, 같은 시각 모든 인스턴스의 CPU p95가 상승했으며
> 디스크 latency는 기준선 안에 있었다. CPU 포화 가설을 동일 부하의 SKU 비교로 검증한다.”

## 실행

Log Analytics에서 다음 쿼리를 실행합니다.

```kusto
Heartbeat
| where TimeGenerated > ago(30m)
| summarize lastSeen=max(TimeGenerated), samples=count() by Computer
| order by Computer asc
```

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace in ("Processor", "Memory", "LogicalDisk")
| summarize avg(Val), max(Val), percentile(Val, 95)
  by bin(TimeGenerated, 1m), Computer, Namespace, Name
| order by TimeGenerated asc
```

상세 쿼리는 [`../TESTING-AND-ANALYSIS.md`](../TESTING-AND-ANALYSIS.md)를 사용합니다.

## 분석 템플릿

```text
테스트:
영향 시작 시각(UTC):
Before p95 / 성공률:
After p95 / 성공률:
상관관계가 있는 지표 2개:
가설:
반증:
다음 검증:
```

## 통과 기준

단일 지표가 아니라 최소 2개 지표와 시간 상관관계를 사용해 결론을 작성합니다.

## 다음 단계

[`../07-tune/README.md`](../07-tune/README.md)
