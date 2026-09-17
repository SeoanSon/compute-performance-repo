# Azure Compute Performance & Operations Lab

운영 환경에서 Azure VM과 VM Scale Set의 성능을 측정하고, 병목을 진단하며, 변경 전후의 효과를 검증하는 실습형 워크숍입니다.

> 이 자료는 리소스 생성 튜토리얼이 아니라 **운영 가능한 Compute를 설계·관측·튜닝·복구하는 방법**에 초점을 둡니다.

## 실행 문서

처음부터 실습 환경을 만들고 결과를 분석하려면 다음 순서로 진행합니다.

1. [`DEPLOYMENT.md`](./DEPLOYMENT.md): Azure CLI로 팀별 VMSS, 네트워크, Log Analytics, 샘플 API 배포
2. [`TESTING-AND-ANALYSIS.md`](./TESTING-AND-ANALYSIS.md): 기준선·부하 테스트·장애 주입 실행, KQL 분석, 튜닝 판정
3. [`ASSESSMENT.md`](./ASSESSMENT.md): 사전·사후 평가, 실기 시나리오, 전후 차이 판정
4. [`FACILITATOR-GUIDE.md`](./FACILITATOR-GUIDE.md): 진행자 준비·힌트·완료 기준

`scripts/install-order-api.sh`는 실습용 `/healthz`, `/readyz`, `/api/orders`, `/api/report` 서비스를 VMSS 인스턴스에 설치합니다. 실제 서비스가 있는 경우에도 동일한 health endpoint 계약을 유지하면 테스트 절차를 재사용할 수 있습니다.

## 1. 워크숍 개요

### 대상

- Azure VM 또는 VMSS를 운영하는 클라우드·플랫폼·SRE 엔지니어
- 성능 문제를 Azure Monitor와 운영 지표로 분석해야 하는 애플리케이션 팀
- VM SKU, Managed Disk, Autoscale, 가용성 구성을 검토하는 아키텍트

### 선수 지식

- Azure Portal 또는 Azure CLI 기본 사용법
- Linux 명령어와 HTTP 서비스에 대한 기본 이해
- CPU, 메모리, IOPS, latency, throughput의 기본 개념

### 학습 목표

워크숍 종료 후 참가자는 다음을 수행할 수 있어야 합니다.

1. VM/VMSS의 성능 기준선(baseline)을 정의하고 측정한다.
2. CPU, 메모리, 디스크, 네트워크 병목을 지표로 구분한다.
3. VM SKU와 Managed Disk 변경을 근거 기반으로 결정한다.
4. VMSS Autoscale, Health Probe, Rolling Upgrade를 검증한다.
5. 장애를 주입하고 Azure Monitor, Activity Log, Boot Diagnostics로 원인을 좁힌다.
6. 변경 전후 성능·비용·운영 리스크를 비교해 개선 백로그를 작성한다.

## 2. 권장 진행 방식

### 기본 정보

| 항목 | 권장 값 |
|---|---|
| 총 시간 | 6시간 30분 |
| 형식 | 짧은 설명 30%, 실습 60%, 리뷰 10% |
| 인원 | 2~3명 1팀 |
| 환경 | 팀별 Azure 구독 또는 사전 준비된 리소스 그룹 |
| 워크로드 | 상태 비저장 HTTP 서비스 + 부하 발생기 |
| 주요 도구 | Azure Monitor, Log Analytics, VM Insights, Azure Load Testing 또는 `stress-ng`/`fio`/`wrk` |

### 시간표

| 시간 | 세션 | 결과물 |
|---:|---|---|
| 00:00–00:45 | 사전 평가·오리엔테이션 및 운영 시나리오 | 개인 사전 점수·팀별 목표 SLO |
| 00:30–01:20 | 기준선 측정 | Baseline Sheet |
| 01:20–02:20 | 부하 테스트와 병목 분석 | Bottleneck Diagnosis |
| 02:20–02:35 | 휴식 |  |
| 02:35–03:25 | SKU·디스크 튜닝 | Tuning Decision Record |
| 03:25–04:20 | VMSS Autoscale·배포 검증 | Scale Test Report |
| 04:20–04:35 | 휴식 |  |
| 04:35–05:35 | 장애 주입 GameDay | Incident Timeline |
| 05:35–06:10 | 비용·운영성 평가 | Improvement Backlog |
| 06:10–06:30 | 사후 평가·팀별 발표 및 회고 | 개인 사후 점수·최종 운영 리포트 |

## 3. 실습 시나리오

### 가상 서비스

참가자는 `Order API`라는 상태 비저장 HTTP 서비스를 운영합니다.

- 평상시 요청률: 50 RPS
- 피크 요청률: 300 RPS
- 목표 응답시간: p95 250ms 이하
- 가용성 목표: 99.9%
- 배포 중 요청 오류율: 1% 미만
- 월간 Compute 예산: 팀별로 지정

서비스 내부에는 다음 선택적 엔드포인트를 포함합니다.

| 엔드포인트 | 용도 |
|---|---|
| `/healthz` | 프로세스 생존 확인 |
| `/readyz` | 트래픽 수신 가능 여부 |
| `/api/orders` | CPU·메모리·네트워크 부하 |
| `/api/report` | 디스크 읽기 부하 |
| `/api/export` | 디스크 쓰기 및 네트워크 전송 부하 |

실제 애플리케이션이 없는 경우에도 동일한 패턴의 샘플 컨테이너나 간단한 HTTP 서비스로 대체할 수 있습니다.

## 4. 권장 토폴로지

```text
                    +----------------------+
                    | Azure Load Balancer  |
                    +----------+-----------+
                               |
                    +----------v-----------+
                    | VM Scale Set         |
                    | min 2 / max 6        |
                    | Order API instances  |
                    +----+------------+-----+
                         |            |
                  +------v----+ +-----v------+
                  | Managed    | | Log        |
                  | Disk       | | Analytics  |
                  +-----------+ +------------+
                                      ^
                                      |
                           Azure Monitor / Alerts
```

워크숍 환경에서는 VMSS를 기본 대상으로 사용하되, VM 한 대만 제공되는 환경에서도 Lab 1~3과 Lab 5의 일부를 수행할 수 있습니다.

## 5. 실습 전 안전 규칙

1. 운영 구독에서 실습하지 않는다. 반드시 별도 구독 또는 격리된 리소스 그룹을 사용한다.
2. 부하 테스트 대상의 주소와 테스트 시간을 명시한다.
3. 공용 IP, SSH/RDP, NSG 규칙은 실습 종료 전에 제거하거나 제한한다.
4. 비용이 발생하는 리소스에는 `workshop`, `owner`, `expiresAt` 태그를 지정한다.
5. 장애 주입은 샘플 리소스에만 수행하며, 종료 조건과 복구 명령을 먼저 기록한다.
6. 참가자는 비밀 값과 연결 문자열을 문서나 캡처에 포함하지 않는다.

## 6. Lab 0 — 운영 목표와 관측 준비

### 목표

측정 전에 “무엇을 정상으로 볼 것인가”를 합의하고, 모든 실습 결과가 같은 시간축과 지표를 사용하도록 준비합니다.

### 작업

1. 팀별 서비스 SLO를 기록합니다.
2. VM/VMSS 인스턴스, OS, 지역, SKU, 디스크 유형을 인벤토리화합니다.
3. Log Analytics Workspace와 VM Insights 연결 상태를 확인합니다.
4. 다음 기본 경고가 존재하는지 확인합니다.

| 영역 | 시작 경고 |
|---|---|
| CPU | 평균 CPU > 75% 10분 |
| 메모리 | 사용률 > 80% 10분 |
| 디스크 | latency 또는 queue depth가 기준선 초과 |
| 네트워크 | NIC throughput이 SKU 한계에 근접 |
| 가용성 | Health probe 실패 또는 heartbeat 중단 |

### 산출물

`baseline-sheet.md` 또는 스프레드시트에 다음을 기록합니다.

```text
측정 창:
서비스 버전:
인스턴스 수:
VM SKU:
OS 디스크:
데이터 디스크:
정상 RPS:
정상 p50/p95/p99:
정상 CPU:
정상 메모리:
정상 디스크 latency:
정상 오류율:
```

## 7. Lab 1 — 성능 기준선 측정

### 목표

부하를 주기 전에 정상 상태의 시스템 특성을 수치로 남깁니다.

### 측정 항목

| 계층 | 필수 지표 | 해석 |
|---|---|---|
| 애플리케이션 | RPS, p50/p95/p99, 4xx/5xx | 사용자 체감 성능 |
| CPU | Percentage, processor queue | CPU 포화 여부 |
| 메모리 | available bytes, paging | 메모리 압박 여부 |
| 디스크 | IOPS, throughput, latency, queue depth | 저장소 병목 |
| 네트워크 | bytes in/out, connection count | NIC·연결 병목 |
| VMSS | instance count, health state | 확장·복구 상태 |

### 실행 절차

1. 10분 동안 평상시 트래픽을 유지합니다.
2. 1분 단위 평균과 p95를 기록합니다.
3. 인스턴스별 값과 전체 평균을 구분합니다.
4. 지표 수집 지연과 빈 구간을 표시합니다.
5. “정상”을 평균 하나가 아닌 **범위**로 정의합니다.

### 통과 기준 예시

- p95 latency가 250ms 이하
- 오류율이 0.5% 이하
- CPU 평균이 60% 이하, 순간 피크가 80% 이하
- 메모리 사용률이 75% 이하
- 디스크 latency가 워크로드 기준선의 2배 이하
- 모든 VMSS 인스턴스가 Ready 상태

## 8. Lab 2 — 부하 테스트와 병목 분석

### 목표

같은 서비스에 서로 다른 부하를 주고 병목의 위치를 지표로 판별합니다.

### 부하 프로파일

| 프로파일 | 지속 시간 | 목적 |
|---|---:|---|
| Warm-up | 5분 | 캐시와 연결 안정화 |
| Steady | 10분 | 기준선 대비 비교 |
| CPU stress | 10분 | CPU 포화 관찰 |
| Disk stress | 10분 | IOPS·latency 관찰 |
| Spike | 5분 | Autoscale 반응 검증 |
| Cool-down | 10분 | 복구와 scale-in 확인 |

### 판별 규칙

| 관찰 결과 | 우선 의심할 원인 | 다음 확인 |
|---|---|---|
| CPU와 run queue가 함께 상승 | CPU 부족 또는 비효율 코드 | 프로세스별 CPU, SKU 비교 |
| 메모리 감소와 paging 증가 | 메모리 부족 | working set, swap/page fault |
| 디스크 latency 상승, IOPS는 한계 근처 | 디스크 성능 한계 | 디스크 tier·caching·queue |
| 네트워크 throughput 증가 후 latency 상승 | NIC 또는 연결 한계 | VM SKU 네트워크 제한 |
| 모든 인스턴스가 정상인데 p95 상승 | LB, 외부 의존성, 애플리케이션 | dependency latency |
| 새 인스턴스가 생겨도 오류 지속 | warm-up 또는 readiness 문제 | health probe·startup time |

### 판정 원칙

- 단일 지표만으로 병목을 결론 내리지 않습니다.
- 애플리케이션 지표와 플랫폼 지표의 시간대를 겹쳐 봅니다.
- 평균보다 p95/p99와 오류율을 우선합니다.
- 변경 전 최소 한 번, 변경 후 동일한 부하를 실행합니다.

## 9. Lab 3 — VM SKU와 Managed Disk 튜닝

### 목표

“더 큰 VM”이 아니라 병목에 맞는 변경을 선택하고, 효과가 없을 때 되돌릴 근거를 남깁니다.

### 비교 후보 예시

| 병목 | 비교 후보 | 확인 포인트 |
|---|---|---|
| 균형형 웹/API | D 계열 후보 2개 | CPU·메모리·네트워크·가격 |
| CPU 중심 | F 계열과 D 계열 | RPS/vCPU와 p95 |
| 메모리 중심 | E 계열과 D 계열 | 메모리 headroom과 비용 |
| 디스크 중심 | Premium SSD tier 후보 | IOPS, throughput, latency |
| 간헐 부하 | B 계열과 D 계열 | 크레딧 고갈과 tail latency |

SKU 이름과 한계는 지역·세대·운영체제에 따라 달라질 수 있으므로, 실제 변경 전 Azure 공식 크기 문서와 구독 quota를 확인합니다.

### 변경 기록 템플릿

```text
변경 ID:
가설: 예) CPU 포화가 p95 상승의 주원인이다.
변경 대상:
변경 전:
변경 후:
검증 부하:
성능 변화:
비용 변화:
운영 리스크:
롤백 방법:
결론: 채택 / 보류 / 기각
```

### 성공 기준

- 동일 부하에서 p95가 최소 20% 개선되거나
- 동일 성능에서 시간당 비용이 최소 15% 감소하고
- 오류율·가용성·배포 시간이 악화되지 않아야 합니다.

## 10. Lab 4 — VMSS Autoscale와 배포 검증

### 목표

Autoscale이 “늘어나는지”가 아니라, SLO를 지키면서 적절한 시점에 늘고 안전하게 줄어드는지 검증합니다.

### 검증 항목

1. CPU 기반 scale-out 조건과 cooldown을 확인합니다.
2. 요청률 또는 queue length 기반 정책을 비교합니다.
3. 새 인스턴스가 Ready 되기 전 트래픽을 받지 않는지 확인합니다.
4. rolling upgrade 중 오류율과 p95를 관찰합니다.
5. scale-in 시 연결 중인 요청이 중단되지 않는지 확인합니다.
6. 최소·최대 인스턴스 수와 quota 여유를 기록합니다.

### 기록할 지표

| 지표 | 의미 |
|---|---|
| scale decision time | 확장 결정까지 걸린 시간 |
| instance provisioning time | 새 인스턴스 준비 시간 |
| warm-up time | 실제 트래픽 처리 가능 시간 |
| SLO breach duration | SLO를 벗어난 시간 |
| scale-in recovery | 축소 후 안정화 시간 |
| cost per request | 확장 정책의 비용 효율 |

### 권장 토론

- CPU가 낮아도 latency가 높은 경우 어떤 metric이 더 적합한가?
- scale-out을 너무 빠르게 하면 어떤 비용·안정성 문제가 생기는가?
- rolling upgrade와 autoscale이 동시에 발생하면 어떤 순서로 보호할 것인가?

## 11. Lab 5 — 장애 주입 GameDay

### 목표

문제 발생 후 “누가 무엇을 언제 확인하는가”를 표준화하고, 복구 시간을 측정합니다.

### 장애 카드

#### 카드 A: CPU 포화

- 증상: p95 상승, CPU 95% 이상
- 확인: VM metric, process usage, request rate
- 완화: 부하 중지, scale-out, SKU 변경 검토
- 복구 판정: p95가 기준선의 1.2배 이하로 10분 유지

#### 카드 B: 디스크 latency 급증

- 증상: `/api/report` timeout, 디스크 queue 상승
- 확인: disk IOPS/throughput/latency, 애플리케이션 timeout
- 완화: 부하 중지, disk tier 또는 caching 검토
- 복구 판정: 오류율 0.5% 이하, latency 정상 범위 복귀

#### 카드 C: Health Probe 실패

- 증상: VM은 Running이지만 LB에서 제외
- 확인: `/healthz`와 `/readyz`, NSG, 서비스 상태, probe 설정
- 완화: 원인 수정 후 인스턴스 drain/복귀
- 복구 판정: Ready 인스턴스가 최소 수 이상이고 오류율 정상

#### 카드 D: Scale-out 실패

- 증상: 인스턴스 수가 증가하지 않음
- 확인: Activity Log, autoscale run history, quota, capacity, 확장 오류
- 완화: quota·SKU·지역 대안 확인, 안전한 수동 확장
- 복구 판정: 목표 인스턴스 수와 SLO 회복

### Incident Timeline

```text
T+00:00 탐지:
T+00:05 영향 범위:
T+00:10 초기 가설:
T+00:15 확인한 지표:
T+00:20 완화 조치:
T+00:30 서비스 회복:
T+00:40 원인 확정:
T+00:50 후속 조치:
```

## 12. Lab 6 — 비용과 운영성 평가

### 평가 항목

| 영역 | 질문 |
|---|---|
| 성능 | 동일 SLO를 더 적은 인스턴스로 달성할 수 있는가? |
| 비용 | 평균 인스턴스 수와 피크 인스턴스 수가 합리적인가? |
| 안정성 | 단일 장애가 전체 서비스로 전파되지 않는가? |
| 운영 | 패치·배포·롤백 절차가 자동화되어 있는가? |
| 관측 | 탐지·진단·복구에 필요한 지표가 있는가? |
| 용량 | quota와 지역 capacity를 사전에 검증하는가? |

### 개선 백로그 템플릿

| 우선순위 | 문제 | 근거 | 조치 | 예상 효과 | 담당 | 기한 |
|---|---|---|---|---|---|---|
| P0/P1/P2 |  | 지표·로그·장애 기록 |  |  |  |  |

## 13. 최종 제출물

각 팀은 다음 5개를 제출합니다.

1. **Baseline Sheet**: 정상 상태와 측정 방법
2. **Bottleneck Diagnosis**: 병목 가설·증거·결론
3. **Tuning Decision Record**: 변경 전후 성능·비용 비교
4. **Incident Runbook**: 장애 탐지·완화·복구 절차
5. **Improvement Backlog**: 우선순위가 있는 후속 작업

## 14. 평가 루브릭

| 항목 | 0점 | 1점 | 2점 |
|---|---|---|---|
| 기준선 | 측정 없음 | 지표 일부 기록 | 반복 가능한 기준선 |
| 분석 | 단일 지표 추측 | 일부 상관관계 | 시간축 기반 증거 |
| 튜닝 | 변경만 수행 | 전후 비교 | 가설·효과·롤백 포함 |
| Autoscale | 동작 확인만 | 기본 검증 | SLO·warm-up·scale-in 검증 |
| 장애 대응 | 복구 실패 | 복구는 가능 | 탐지·완화·근본원인·후속조치 |
| 운영성 | 수동 절차 | 일부 자동화 | 재사용 가능한 산출물 |

## 15. 확장 트랙

기본 Lab 이후 다음 심화 과정으로 확장할 수 있습니다.

- **VMSS 운영 심화**: Flexible orchestration, rolling upgrade, instance protection
- **GPU Compute 성능**: GPU utilization, quota, throughput per dollar
- **Compute DR GameDay**: Azure Compute Gallery, Site Recovery, 지역 장애
- **비용 최적화**: Reservations, Savings Plan, Spot, 유휴 리소스
- **보안 운영**: Managed Identity, JIT access, Defender for Servers, 디스크 암호화
- **HPC/배치 운영**: 고성능 디스크, 병렬 처리, 작업 큐, capacity 계획
