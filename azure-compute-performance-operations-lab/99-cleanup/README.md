# 99. 정리하기

## 이 단계에서 배우는 것

- 운영 실습에서 결과 보존과 리소스 정리가 왜 기술 역량의 일부인지
- 테스트 환경을 방치했을 때 발생하는 비용·보안·운영 리스크
- 다음 팀이 재현할 수 있도록 상태와 결과를 남기는 방법

## 결과 보존

```powershell
Get-ChildItem $artifacts -Recurse | Select-Object FullName,Length
az vmss list-instances -g $rg -n $vmss -o json |
  Set-Content (Join-Path $artifacts "final-vmss-state.json")
```

## 리소스 삭제

결과 파일을 제출한 뒤에만 실행합니다.

```powershell
az group delete -n $rg --yes --no-wait
```

## 완료 기준

- 결과 파일 보존
- 부하 생성 중지
- Public IP·NSG·VMSS 삭제 확인
- 비용이 계속 발생하는 리소스가 없음
