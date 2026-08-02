# ADR-001: 체크포인트 S3 버킷을 Terraform이 직접 생성·소유

## Status

Accepted (2026-08-02)

## Context

기존 구현에는 세 가지 문제가 겹쳐 있었다.

1. Terraform은 체크포인트 버킷을 **생성하지 않은 채**, IAM 정책만 고정 이름
   `isaac-lab-checkpoints`에 `s3:GetObject/PutObject/ListBucket`을 부여했다.
2. `user_data.sh`의 `sync-checkpoints` 래퍼는 셸 폴백
   `$${CHECKPOINT_BUCKET:-isaac-lab-checkpoints}`를 사용했는데, 이 변수는
   어디에서도 설정되지 않아(cron은 빈 환경으로 실행) 항상 고정 이름으로
   해석되었다. `templatefile()`에 전달되는 `checkpoint_bucket` 변수는 스크립트에
   전혀 보간되지 않았다.
3. S3 버킷 이름은 **글로벌 네임스페이스**다. 제3자가 `isaac-lab-checkpoints`를
   선점(namesquatting)하고 크로스 계정 `s3:PutObject`를 허용하면, 기본 설정으로
   배포된 모든 워크샵 인스턴스가 30분마다 체크포인트를 외부 계정 버킷으로
   전송한다. 보안 리뷰에서 Medium 심각도(확신도 8/10)로 확정된 취약점이다.

부차적으로, 사용자가 `terraform.tfvars`에 커스텀 버킷 이름을 지정해도 스크립트는
하드코딩된 이름을 계속 사용하므로 IAM AccessDenied로 백업(Spot 중단 대비
안전장치)이 조용히 실패하는 결함도 있었다.

## Decision

1. **버킷을 Terraform이 직접 생성** — `aws_s3_bucket.checkpoints`, 이름은
   `${var.checkpoint_bucket}-${account_id}`. 계정 ID 접미사로 글로벌 유일성을
   확보하고, 소유권이 항상 배포 계정에 있음을 보장한다.
2. **퍼블릭 액세스 전면 차단** — `aws_s3_bucket_public_access_block` 4개 플래그
   모두 활성화.
3. **IAM 정책은 버킷 리소스 ARN을 참조** — `aws_s3_bucket.checkpoints.arn`.
   소유하지 않은 버킷에 권한이 부여될 수 없는 구조로 변경.
4. **렌더 타임 보간** — `user_data.sh`의 S3 경로를 `${checkpoint_bucket}`
   (단일 달러, templatefile 치환)로 변경해 cron 환경 의존을 제거.
5. **`force_destroy = true`** — 워크샵 종료 시 `terraform destroy`가 버킷
   비우기 실패로 중단되지 않도록 한다.

## Consequences

- (+) 네임스쿼팅을 통한 체크포인트 유출 경로 원천 차단.
- (+) 커스텀 `checkpoint_bucket` 값이 IAM과 스크립트에 일관되게 반영되어
  조용한 동기화 실패가 사라짐.
- (+) 버킷 수명주기가 코드로 관리되고 `terraform output checkpoint_bucket`으로
  실제 이름 확인 가능.
- (−) `terraform destroy`가 S3에 백업된 체크포인트까지 삭제한다. 보존이
  필요한 결과물은 destroy 전에 로컬로 다운로드해야 한다 (Lab 7에서 안내).
- (−) 버킷 이름에 AWS 계정 ID가 포함된다. AWS는 계정 ID를 비밀로 취급하지
  않으므로 수용 가능한 트레이드오프다.
