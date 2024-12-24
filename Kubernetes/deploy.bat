@echo off
echo Starting Aurora Kubernetes deployment...

timeout /t 5 /nobreak

REM Create Kind cluster
echo Creating Kind cluster...
kind create cluster --config kind-config.yaml --name aurora-cluster
if %errorlevel% neq 0 (
    echo Failed to create Kind cluster
    exit /b %errorlevel%
)

echo.
echo Deployment completed successfully!
echo Waiting for pod to be ready...
timeout /t 10 /nobreak

REM Show deployment status
echo.
echo Deployment Status:
kubectl get pods -o wide
echo.
echo Service Status:
kubectl get services
echo.
echo You can access the service at http://localhost:30080
