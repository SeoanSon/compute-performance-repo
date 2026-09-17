# 07. 튜닝하기

## 목표

VM SKU 또는 Managed Disk 변경을 데이터와 롤백 조건에 근거해 결정합니다.

## 실행 순서

1. 기준선 CSV를 보존합니다.
2. 변경 가설을 한 문장으로 작성합니다.
3. 변경 전 SKU·디스크·인스턴스 수를 기록합니다.
4. 한 가지 변경만 적용합니다.
5. `04-baseline`과 동일한 부하를 실행합니다.
6. Before/After 표를 채웁니다.

## 판정표

| 항목 | Before | After | 판정 |
|---|---:|---:|---|
| p95 latency |  |  |  |
| p99 latency |  |  |  |
| SuccessRate |  |  |  |
| Max CPU |  |  |  |
| Disk latency |  |  |  |
| 시간당 비용 |  |  |  |

## 통과 기준

- p95 20% 개선, 또는 동일 성능에서 비용 15% 절감
- 오류율·가용성 악화 없음
- 롤백 방법 기록

## 다음 단계

[`../08-autoscale/README.md`](../08-autoscale/README.md)

