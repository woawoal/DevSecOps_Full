@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM Change to script directory
cd /d "%~dp0"

echo Starting Jenkins Service Deployment...

REM Build Jenkins Docker image
echo Building Jenkins Docker image...
docker build -t jenkins-kubectl:latest .
if %errorlevel% neq 0 (
    echo Failed to build Docker image
    exit /b %errorlevel%
)

REM Load the image into kind cluster
echo Loading image into kind cluster...
kind load docker-image jenkins-kubectl:latest --name devsecops-cluster
if %errorlevel% neq 0 (
    echo Failed to load image into kind cluster
    exit /b %errorlevel%
)

echo Deploying Jenkins to Kubernetes...

REM Store the original directory
set "ORIGINAL_DIR=%CD%"

echo.
echo Checking cluster nodes...
kubectl get nodes --show-labels | findstr "jenkins"
if %errorlevel% neq 0 (
    echo ERROR: No node with purpose=jenkins label found
    echo Please make sure the cluster is properly configured
    exit /b 1
)

echo.
echo Checking for ngrok auth token...
kubectl get secret ngrok-credentials > nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: ngrok-credentials secret not found
    echo Please create the secret with your ngrok auth token:
    echo kubectl create secret generic ngrok-credentials --from-literal=auth-token=your-token
    exit /b 1
)

echo.
echo Cleaning up existing resources...
kubectl delete deployment,service -l app=jenkins --ignore-not-found=true
ping -n 6 127.0.0.1 > nul

echo.
echo Applying Kubernetes configurations...

REM Delete existing Jenkins deployment and related resources
echo Cleaning up existing Jenkins resources...
kubectl delete deployment jenkins --ignore-not-found
kubectl delete configmap jenkins-kubeconfig --ignore-not-found
kubectl delete -f "%~dp0k8s\jenkins-rbac.yaml" --ignore-not-found

REM Create ConfigMap for kubeconfig
echo Creating kubeconfig ConfigMap...
kubectl create configmap jenkins-kubeconfig --from-file=config="%~dp0config\kubeconfig"

REM Apply RBAC settings
echo Applying RBAC settings...
kubectl apply -f "%~dp0k8s\jenkins-rbac.yaml"

REM Apply PV and PVC
echo Creating persistent volume and claim...
kubectl apply -f "%~dp0k8s\jenkins-pv.yaml"
if %errorlevel% neq 0 (
    echo Failed to create persistent volume
    cd "%ORIGINAL_DIR%"
    exit /b %errorlevel%
)

REM Deploy Jenkins
echo Deploying Jenkins...
kubectl apply -f "%~dp0k8s\jenkins-deployment.yaml"
if %errorlevel% neq 0 (
    echo Failed to deploy Jenkins
    cd "%ORIGINAL_DIR%"
    exit /b %errorlevel%
)

REM Apply Service
echo Creating Jenkins service...
kubectl apply -f "%~dp0k8s\jenkins-service.yaml"
if %errorlevel% neq 0 (
    echo Failed to create service
    cd "%ORIGINAL_DIR%"
    exit /b %errorlevel%
)

REM Create Ngrok secret if not exists
echo Checking Ngrok secret...
kubectl get secret ngrok-credentials > nul 2>&1
if %errorlevel% neq 0 (
    echo Please enter your Ngrok authtoken:
    set /p NGROK_TOKEN=
    kubectl create secret generic ngrok-credentials --from-literal=auth-token=%NGROK_TOKEN%
)

echo.
echo Waiting for Jenkins pod to be ready...
:wait_pod
for /f "tokens=1,2,3 delims= " %%a in ('kubectl get pods -l app^=jenkins ^| findstr "jenkins"') do (
    set "POD_NAME=%%a"
    set "READY=%%b"
    set "STATUS=%%c"
)
if "%READY%"=="2/2" (
    if "%STATUS%"=="Running" (
        goto :pod_ready
    )
)
echo Current status: %READY% containers ready ^| Pod status: %STATUS%
echo Waiting for both Jenkins and Ngrok containers to be ready...
ping -n 6 127.0.0.1 > nul
goto :wait_pod

:pod_ready
echo.
echo Jenkins pod is ready!

REM Wait a bit for Jenkins to initialize
ping -n 11 127.0.0.1 > nul

echo.
echo Getting Jenkins initial admin password...
for /f "tokens=1" %%i in ('kubectl get pods -l app^=jenkins -o jsonpath^="{.items[0].metadata.name}"') do (
    echo Initial admin password:
    kubectl exec %%i -c jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
)

echo.
echo Jenkins is available at:
echo - Web UI: http://localhost:8080
echo - JNLP : localhost:50000

echo.
echo Waiting for Ngrok tunnel to be established...
ping -n 11 127.0.0.1 > nul

echo.
echo Ngrok tunnel information:
for /f "tokens=1" %%i in ('kubectl get pods -l app^=jenkins -o jsonpath^="{.items[0].metadata.name}"') do (
    echo Ngrok logs:
    kubectl logs %%i -c ngrok | findstr "url="
)

echo.
echo Setup completed successfully!
echo.
echo Jenkins URLs:
echo - Local  : http://localhost:8080
for /f "tokens=1" %%i in ('kubectl get pods -l app^=jenkins -o jsonpath^="{.items[0].metadata.name}"') do (
    for /f "tokens=2 delims==" %%u in ('kubectl logs %%i -c ngrok ^| findstr "url="') do (
        echo - Public : %%u
    )
)

cd "%ORIGINAL_DIR%"
endlocal