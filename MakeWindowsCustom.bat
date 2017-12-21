@echo off
:: usage: "MakeWindows.bat Release|Debug"

:: Release or Debug
set "CONFIG=%~1"

if "%CONFIG%" == "" echo ERROR: CONFIG is not set, example of usage: "MakeWindows.bat Release" && pause && exit /b

set "URHO3D_SRC_DIR=Urho3D/Source"
set MSBUILD="C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe"

rmdir bin\Desktop /s /q 2>NUL
rmdir bin\nugets /s /q 2>NUL
del Urho3D\Urho3D_Windows\lib\*.lib 2>NUL

::@echo on

rem can not get x86 to build right now...
::call :buildNative x86
call :buildNative x64

:: build .NET bindings for Desktop framework
%MSBUILD% Bindings\Desktop\Urho.Desktop.csproj /p:Configuration=%CONFIG% /p:Platform=AnyCPU

:: build WPF extension
%MSBUILD% Extensions\Urho.Extensions.Wpf\Urho.Extensions.Wpf.csproj /p:Configuration=%CONFIG% /p:Platform=AnyCPU

:: download nuget
if not exist "bin\nuget.exe" (
    echo Downloading nuget.exe...
    powershell -command "& { (New-Object Net.WebClient).DownloadFile('https://dist.nuget.org/win-x86-commandline/latest/nuget.exe', 'bin\\nuget.exe') }"
)

:: build nuget packages
mkdir bin\nugets
bin\nuget.exe pack Urho.Custom.OpenGL.nuspec -OutputDirectory bin\nugets
bin\nuget.exe pack Urho.Custom.OpenGL.Wpf.nuspec -OutputDirectory bin\nugets
bin\nuget.exe pack Urho.Custom.DirectX11.nuspec -OutputDirectory bin\nugets
bin\nuget.exe pack Urho.Custom.DirectX11.Wpf.nuspec -OutputDirectory bin\nugets

goto :eof

:prepareBuildFiles
    set renderflags=%1
    set renderflags=%renderflags:"=%

    if "%PLATFORM%" == "x64" (set "TARGET=Visual Studio 15 Win64") else (set "TARGET=Visual Studio 15")

    cmake -E make_directory ../Urho3D_Windows
    cmake -E chdir ../Urho3D_Windows cmake -G "%TARGET%" ../Urho3D_Windows %renderflags% -DURHO3D_PCH=0 -DURHO3D_LUA=0 -DURHO3D_ANGELSCRIPT=0 -VS=%VS_VER% ../../%URHO3D_SRC_DIR%/
goto :eof

:buildNative
    set PLATFORM=%1

    :: prepare build files for OpenGL
    del Urho3D\Urho3D_Windows\CMakeCache.txt 2>NUL
    pushd %CD%\Urho3D\Source 
        call :prepareBuildFiles "-DURHO3D_OPENGL=1 -DURHO3D_D3D11=0"
    popd
    pushd %CD%\Urho3D\Urho3D_Windows
        :: build Urho3D lib targeting OpenGL
        cmake --build . --target Urho3D --config %CONFIG% 

        :: build mono wrapper dll
        move lib\Urho3D.lib lib\Urho3D_opengl_%PLATFORM%.lib
        %MSBUILD% MonoUrho.Windows\MonoUrho.Windows.vcxproj /p:Configuration=%CONFIG% /p:Platform=%PLATFORM%

        :: build tools (not related to OpenGL)
        :: TODO: no need to build these in both x86 and x64 i guess...
        cmake --build . --target PackageTool --config %CONFIG%
        cmake --build . --target AssetImporter --config %CONFIG%
    popd

    :: prepare build files for DirectX11
    del Urho3D\Urho3D_Windows\CMakeCache.txt 2>NUL
    pushd %CD%\Urho3D\Source 
        call :prepareBuildFiles "-DURHO3D_OPENGL=0 -DURHO3D_D3D11=1"
    popd

    :: build Urho3D lib targeting DirectX11
    pushd %CD%\Urho3D\Urho3D_Windows
        cmake --build . --target Urho3D --config %CONFIG% 

        :: build mono wrapper dll
        move lib\Urho3D.lib lib\Urho3D_d3d11_%PLATFORM%.lib
        %MSBUILD% MonoUrho.Windows\MonoUrho.WindowsD3D.vcxproj /p:Configuration=%CONFIG% /p:Platform=%PLATFORM%
    popd
goto :eof

