@echo off
setlocal enabledelayedexpansion

REM Find kind executable
set "KIND_PATH="
for %%i in (kind.exe) do set "KIND_PATH=%%~$PATH:i"
if defined KIND_PATH (
    echo Found kind at: "%KIND_PATH%"
) else (
    echo Error: kind.exe not found in PATH
    exit /b 1
)

REM Define variables
set "REPO_NAME=Wargame"
set "REPO_URL=https://github.com/kimbeomjun90/devsecops_web.git"
set "IMAGE_NAME=redrayn/wargame:latest"
set "NAMESPACE=wargame"

REM Check for repository
echo Checking for %REPO_NAME% repository...
if not exist "%REPO_NAME%" (
    echo Cloning repository...
    git clone %REPO_URL%
) else (
    echo Repository exists, updating...
    cd %REPO_NAME%
    git pull
    cd ..
)

REM Build Docker image
echo.
echo Building Docker image...
docker build -t %IMAGE_NAME% %REPO_NAME%

REM Verify Docker image
echo.
echo Verifying Docker image...
docker image inspect %IMAGE_NAME% >nul 2>&1
if errorlevel 1 (
    echo Failed to build Docker image
    exit /b 1
)

REM Load image to Kind cluster
echo.
echo Loading image to Kind cluster...
echo Debug: Current directory is: %CD%
echo Debug: Image name is: %IMAGE_NAME%
echo Debug: Kind executable is: "%KIND_PATH%"

echo Debug: Saving Docker image to tar...
docker save %IMAGE_NAME% -o temp-image.tar
if errorlevel 1 (
    echo Failed to save Docker image
    exit /b 1
)

echo Debug: Loading image archive to Kind cluster...
kind load image-archive temp-image.tar --name devsecops-cluster
if errorlevel 1 (
    echo Failed to load image to Kind cluster
    del temp-image.tar
    exit /b 1
)
del temp-image.tar

REM Create namespace if it doesn't exist
echo.
echo Creating namespace if it doesn't exist...
kubectl get namespace %NAMESPACE% >nul 2>&1
if errorlevel 1 (
    kubectl create namespace %NAMESPACE%
)

REM Apply Kubernetes configurations
echo.
echo Applying Kubernetes configurations...
kubectl apply -f k8s/db-init-configmap.yaml -n %NAMESPACE%
kubectl apply -f k8s/db-deployment.yaml -n %NAMESPACE%
kubectl apply -f k8s/wargame-deployment.yaml -n %NAMESPACE%
kubectl apply -f k8s/services.yaml -n %NAMESPACE%

REM Wait for deployments to be ready
echo.
echo Waiting for deployments to be ready...
kubectl rollout status deployment/wargame-deployment -n %NAMESPACE%
if errorlevel 1 (
    echo Failed to deploy wargame-deployment
    exit /b 1
)

echo.
echo All deployments completed successfully
echo.

REM Check final status
echo Checking pod status...
kubectl get pods -n %NAMESPACE%
echo.
echo Checking service status...
kubectl get services -n %NAMESPACE%

endlocal