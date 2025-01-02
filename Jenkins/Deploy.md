# Jenkins CI/CD 파이프라인 구축 가이드

## 1. 필수 플러그인 설치
Jenkins 관리 > Plugins에서 다음 플러그인들을 설치:
- Docker Pipeline
- Docker plugin
- Kubernetes CLI Plugin
- Kubernetes plugin
- Generic Webhook Trigger Plugin
- GitHub Integration Plugin

## 2. Jenkins 자격 증명 설정
Jenkins 관리 > Credentials > System > Global credentials에서 다음 자격 증명 추가:

1. GitHub 자격 증명
   - Kind: Username with password
   - ID: github

2. Docker Hub 자격 증명
   - Kind: Username with password
   - ID: dockerhub

## 3. GitHub 설정
1. GitHub 저장소 설정
   - 저장소: https://github.com/JJH0204/Wargame.git
   - GitHub Actions workflow 설정으로 Docker 이미지 자동 빌드 및 푸시

## 4. Docker Hub 설정
1. Docker Hub 저장소 생성
   - 저장소 이름: krjaeh0/wargame

2. 웹훅 설정
   - Settings > Webhooks
   - Webhook URL: ${NGROK_URL}/generic-webhook-trigger/invoke?token=wargame-webhook-token

## 5. Jenkins 파이프라인 설정
1. 새로운 파이프라인 생성
   - 이름: wargame-pipeline
   - 유형: Pipeline

2. 파이프라인 구성
   - Build Triggers > Generic Webhook Trigger 설정
     - Token: wargame-webhook-token
     - Post content parameters:
       - Variable: DOCKER_TAG
       - Expression: $.push_data.tag
       - JSONPath 선택
       - Variable: DOCKER_REPO
       - Expression: $.repository.repo_name
       - JSONPath 선택

3. 파이프라인 스크립트 설정
   - Kubernetes 배포 스크립트 추가
   - Docker 이미지 업데이트 로직 구현
   - 자동 배포 설정

## 6. ngrok 설정
1. ngrok 설치 및 실행
   ```bash
   ngrok config add-authtoken ${NGROK_TOKEN}
   ngrok http 8080
   ```

2. 생성된 URL을 Docker Hub 웹훅 설정에 사용

## 7. Kubernetes 설정
1. Deployment 및 Service 생성
   ```yaml
   # deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: wargame-deployment
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: wargame
     template:
       metadata:
         labels:
           app: wargame
       spec:
         containers:
         - name: wargame
           image: redrayn/wargame:latest
           ports:
           - containerPort: 80
   ```

   ```yaml
   # service.yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: wargame-web-service
   spec:
     type: NodePort
     ports:
     - port: 80
       targetPort: 80
       nodePort: 30080
     selector:
       app: wargame
   ```

## 8. 자동화 배포 프로세스
1. 코드 변경사항을 GitHub에 푸시
2. GitHub Actions가 Docker 이미지 빌드 및 Docker Hub에 푸시
3. Docker Hub가 Jenkins에 웹훅 전송
4. Jenkins 파이프라인이 트리거되어 새 이미지로 Kubernetes 배포 업데이트

## 9. 테스트 및 검증
1. 파드 상태 확인
   ```bash
   kubectl get pods
   ```

2. 서비스 상태 확인
   ```bash
   kubectl get services
   ```

3. 웹 서비스 접속 테스트
   ```
   http://localhost:30080
   ```

# Credentials (DO NOT STORE TOKENS HERE - Use Jenkins Credentials Manager)
- GitHub: Use Jenkins Credentials Manager
- Jenkins: Use Jenkins Credentials Manager
- Ngrok: Use Jenkins Credentials Manager
- Docker Hub: Use Jenkins Credentials Manager

# Webhook URLs
${NGROK_URL}
${WEBHOOK_URL}