# 06. 분석하기

## 목표

사용자 영향과 Azure 플랫폼 지표를 같은 시간축에서 비교해 병목 원인을 설명합니다.

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

