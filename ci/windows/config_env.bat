setlocal enabledelayedexpansion

set work_dir=%cd%
echo work_dir=%work_dir%>> %GITHUB_ENV%
if not defined cache_dir (
    set "cache_dir=%work_dir%\..\cache"
    echo cache_dir=%cache_dir%>> %GITHUB_ENV%
)

if not exist %cache_dir% mkdir %cache_dir%
if not exist %cache_dir%\tools (
    cd /d %cache_dir%
    python -m pip install wget
    python -c "import wget;wget.download('https://paddle-ci.gz.bcebos.com/window_requirement/tools.zip')"
    tar xf tools.zip
    cd /d %work_dir%
)

pip config set global.trusted-host pypi.org
pip config set global.trusted-host files.pythonhosted.org
pip config set global.trusted-host pypi.python.org
pip config set global.index-url https://pypi.org/simple
git config --global core.longpaths true
git config --global user.name "PaddleCI"
git config --global user.email "paddle_ci@example.com"

git remote add upstream https://github.com/PaddlePaddle/Paddle.git

git --no-pager pull upstream %BRANCH% --no-edit
if %errorlevel% NEQ 0 exit /b 1
if exist .git\index.lock del .git\index.lock 2>NUL

rem ------ARM64: Use Ninja generator (no Visual Studio ARM64 cross-compile needed on native runner)------
if not defined GENERATOR echo GENERATOR=Ninja>> %GITHUB_ENV%

rem ------ARM64: No TensorRT, no GPU, no MKL, no AVX------
if not defined WITH_TENSORRT echo WITH_TENSORRT=OFF>> %GITHUB_ENV%
if not defined WITH_GPU    echo WITH_GPU=OFF>> %GITHUB_ENV%
if not defined WITH_MKL    echo WITH_MKL=OFF>> %GITHUB_ENV%
if not defined WITH_AVX    echo WITH_AVX=OFF>> %GITHUB_ENV%
if not defined WITH_ARM    echo WITH_ARM=ON>> %GITHUB_ENV%

rem ------Common build flags------
if not defined WITH_TESTING          echo WITH_TESTING=OFF>> %GITHUB_ENV%
if not defined MSVC_STATIC_CRT       echo MSVC_STATIC_CRT=ON>> %GITHUB_ENV%
if not defined WITH_PYTHON (
    set WITH_PYTHON=ON
    echo WITH_PYTHON=ON>> %GITHUB_ENV%
)
if not defined ON_INFER              echo ON_INFER=ON>> %GITHUB_ENV%
if not defined WITH_ONNXRUNTIME      echo WITH_ONNXRUNTIME=OFF>> %GITHUB_ENV%
if not defined WITH_INFERENCE_API_TEST echo WITH_INFERENCE_API_TEST=OFF>> %GITHUB_ENV%
if not defined WITH_STATIC_LIB       echo WITH_STATIC_LIB=ON>> %GITHUB_ENV%
if not defined WITH_UNITY_BUILD      echo WITH_UNITY_BUILD=ON>> %GITHUB_ENV%
if not defined WITH_SHARED_PHI       echo WITH_SHARED_PHI=ON>> %GITHUB_ENV%
if not defined NEW_RELEASE_ALL       echo NEW_RELEASE_ALL=ON>> %GITHUB_ENV%
if not defined NEW_RELEASE_PYPI      echo NEW_RELEASE_PYPI=OFF>> %GITHUB_ENV%
if not defined NEW_RELEASE_JIT       echo NEW_RELEASE_JIT=OFF>> %GITHUB_ENV%
if not defined WITH_CPP_TEST         echo WITH_CPP_TEST=OFF>> %GITHUB_ENV%
if not defined WITH_NIGHTLY_BUILD    echo WITH_NIGHTLY_BUILD=OFF>> %GITHUB_ENV%

rem ------Cache / sccache flags------
if not defined WITH_TPCACHE  echo WITH_TPCACHE=OFF>> %GITHUB_ENV%
if not defined WITH_CACHE    echo WITH_CACHE=OFF>> %GITHUB_ENV%
if not defined WITH_SCCACHE  echo WITH_SCCACHE=ON>> %GITHUB_ENV%

rem ------ARM64: TensorRT root not relevant, but define a placeholder to avoid unset-variable issues------
if not defined TENSORRT_ROOT echo TENSORRT_ROOT=D:/TensorRT>> %GITHUB_ENV%

if not defined INFERENCE_DEMO_INSTALL_DIR echo INFERENCE_DEMO_INSTALL_DIR=%cache_dir:\=/%/inference_demo>> %GITHUB_ENV%
if not defined LOG_LEVEL         echo LOG_LEVEL=normal>> %GITHUB_ENV%
if not defined PRECISION_TEST    echo PRECISION_TEST=OFF>> %GITHUB_ENV%
if not defined WIN_UNITTEST_LEVEL echo WIN_UNITTEST_LEVEL=2>> %GITHUB_ENV%
rem LEVEL 0: unittests unrelated to CUDA/TRT or without GPU memory
rem LEVEL 1: unittests unrelated to CUDA/TRT
rem LEVEL 2: run all tests
if not defined NIGHTLY_MODE echo NIGHTLY_MODE=OFF>> %GITHUB_ENV%
if not defined PYTHON_ROOT   echo PYTHON_ROOT=C:\Python313>> %GITHUB_ENV%
if not defined BUILD_DIR     echo BUILD_DIR=build>> %GITHUB_ENV%
if not defined TEST_INFERENCE echo TEST_INFERENCE=OFF>> %GITHUB_ENV%
if not defined WITH_PIP_CUDA_LIBRARIES echo WITH_PIP_CUDA_LIBRARIES=OFF>> %GITHUB_ENV%

echo UPLOAD_TP_FILE=OFF>> %GITHUB_ENV%
echo UPLOAD_TP_CODE=OFF>> %GITHUB_ENV%

echo error_code=0 >> %GITHUB_ENV%
type %cache_dir%\error_code.txt 2>NUL || echo (no prior error_code.txt found, continuing)

rem ------Re-assert long path support------
git config --global core.longpaths true

rem ------Initialize the Python virtual environment------
set "PYTHON_VENV_ROOT=%cache_dir%\python_venv"
echo PYTHON_VENV_ROOT=%PYTHON_VENV_ROOT%>> %GITHUB_ENV%
if not exist %PYTHON_VENV_ROOT% mkdir %PYTHON_VENV_ROOT%
set "PYTHON_EXECUTABLE=%PYTHON_VENV_ROOT%\Scripts\python.exe"
echo PYTHON_EXECUTABLE=%PYTHON_EXECUTABLE%>> %GITHUB_ENV%
%PYTHON_ROOT%\python.exe -m venv --clear %PYTHON_VENV_ROOT%
call "%PYTHON_VENV_ROOT%\Scripts\activate.bat"
if %ERRORLEVEL% NEQ 0 (
    echo activate python virtual environment failed!
    exit /b 5
)
python -m pip install wget
if "%WITH_PYTHON%" == "ON" (
    where python
    where pip
    python -m pip install --upgrade pip
    python -m pip install -r %work_dir%\paddle\scripts\compile_requirements.txt
    if !ERRORLEVEL! NEQ 0 (
        echo pip install compile_requirements.txt failed!
        exit /b 5
    )
    python -m pip install -r %work_dir%\python\requirements.txt
    if !ERRORLEVEL! NEQ 0 (
        echo pip install requirements.txt failed!
        exit /b 5
    )
)
