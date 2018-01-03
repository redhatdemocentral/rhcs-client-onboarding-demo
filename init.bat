@ECHO OFF
setlocal enableextensions enabledelayedexpansion

set PROJECT_HOME=%~dp0
set DEMO=Cloud Client Onboarding Demo
set AUTHORS=Duncan Doyle, Entando, Andrew Block, Eric D. Schabell
set PROJECT=git@github.com:redhatdemocentral/rhcs-client-onboarding-demo.git

REM Adjust these variables to point to an OCP instance.
set OPENSHIFT_USER=openshift-dev
set OPENSHIFT_PWD=devel
set TEMPLATES=support/templates
set HOST_IP=192.168.99.100
set OCP_PRJ=client-onboarding
set GIT_URI="https://github.com/redhatdemocentral/fsi-onboarding-bpm.git"
set FSI_CUSTOMER_REPO="https://github.com/redhatdemocentral/fsi-customer.git"
set FSI_BACKOFFICE_REPO="https://github.com/redhatdemocentral/fsi-backoffice.git"

REM wipe screen.
cls

echo.
echo ########################################################################
echo ##                                                                    ##   
echo ##  Setting up the %DEMO%                       ##
echo ##                                                                    ##   
echo ##                                                                    ##   
echo ##     ####  ####   #   #      ### #   # ##### ##### #####            ##
echo ##     #   # #   # # # # #    #    #   #   #     #   #                ##
echo ##     ####  ####  #  #  #     ##  #   #   #     #   ###              ##
echo ##     #   # #     #     #       # #   #   #     #   #                ##
echo ##     ####  #     #     #    ###  ##### #####   #   #####            ##
echo ##                                                                    ## 
echo ##             #### #      ###  #   # ####                            ##
echo ##        #   #     #     #   # #   # #   #                           ##
echo ##       ###  #     #     #   # #   # #   #                           ##
echo ##        #   #     #     #   # #   # #   #                           ##
echo ##             #### #####  ###   ###  ####                            ##
echo ##                                                                    ##   
echo ##  brought to you by,                                                ##   
echo ##     %AUTHORS%          ##
echo ##                                                                    ##
echo ##  %PROJECT%  ##
echo ##                                                                    ##
echo ########################################################################
echo.

REM Validate OpenShift 
set argTotal=0

for %%i in (%*) do set /A argTotal+=1

if %argTotal% EQU 1 (

    call :validateIP %1 valid_ip

	if !valid_ip! EQU 0 (
	    echo OpenShift host given is a valid IP...
	    set HOST_IP=%1
		echo.
		echo Proceeding with OpenShift host: !HOST_IP!...
	) else (
		echo Please provide a valid IP that points to an OpenShift installation...
		echo.
        GOTO :printDocs
	)

)

if %argTotal% GTR 1 (
    GOTO :printDocs
)


REM make some checks first before proceeding.	
call where oc >nul 2>&1
if  %ERRORLEVEL% NEQ 0 (
	echo OpenShift command line tooling is required but not installed yet... download here:
	echo https://access.redhat.com/downloads/content/290
	GOTO :EOF
)

echo OpenShift commandline tooling is installed...
echo.
echo Logging in to OpenShift as %OPENSHIFT_USER%...
echo.
call oc login %HOST_IP%:8443 --password="%OPENSHIFT_PWD%" --username="%OPENSHIFT_USER%"

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred during 'oc login' command!
	echo.
	GOTO :EOF
)

echo Installing client onboarding process driven applicaiton...
echo.
echo Creating %OCP_PRJ% project...
echo.
call oc new-project %OCP_PRJ% --display-name=%OCP_DESCRIPTION% --description="Process driven client onboarding application scenario." 

echo.
echo Creating secrets and service accounts...
echo.
call oc process -f %TEMPLATES%\secrets-and-accounts.yaml | oc create -f -

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred creating secrets and service accounts!
	echo.
	GOTO :EOF
)

echo.
echo Adding policies to service accounts...
echo.
call oc policy add-role-to-user view system:serviceaccount:%OCP_PRJ%:processserver-service-account

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred adding policies to service accounts!
	echo.
	GOTO :EOF
)

echo.
echo Creating Client Onboarding Build and Deployment config...
echo.
call oc process -f %TEMPLATES%/client-onboarding-process.yaml -p GIT_URI=%GIT_URI% -p GIT_REF="master" -n %OCP_PRJ% | oc create -f - -n %OCP_PRJ%

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred creating client onboarding build and deployment conifg!
	echo.
	GOTO :EOF
)

echo.
echo Creating new app for fsi-customer...
echo.
call oc new-app %FSI_CUSTOMER_REPO% --name fsi-customer

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred during new app creation for fsi-customer!
	echo.
	GOTO :EOF
)

echo
echo "Exposing fsi-customer service..."
echo
oc expose svc fsi-customer --name=entando-fsi-customer

if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred during exposure of fsi-customer service!
	echo.
	GOTO :EOF
)

echo
echo "Creating new app for fsi-backoffice..."
echo
oc new-app "$FSI_BACKOFFICE_REPO" --name fsi-backoffice

echo
echo "Exposing fsi-backoffice service..."
echo
oc expose svc fsi-backoffice --name=entando-fsi-backoffice
	
if not "%ERRORLEVEL%" == "0" (
  echo.
	echo Error occurred during exposure of fsi-backoffice service!
	echo.
	GOTO :EOF
)																				

echo.
echo ========================================================================
echo =                                                                     =
echo =  Login to start exploring the Client Oboarding application:         =
echo =                                                                     =
echo =  http://entando-fsi-backoffice-%OCP_PRJ%.%HOST_IP%.nip.io/fsi-backoffice =
echo =                                                                     =
echo =       [ u:account / p:adminadmin ]                                  =
echo =       [ u:knowledge / p:adminadmin ]                                =
echo =       [ u:legal / p:adminadmin ]                                    =
echo =       [ u:Manager / p:adminadmin ]                                  =
echo =                                                                     =
echo =  http://entando-fsi-customer-%OCP_PRJ%.%HOST_IP%.nip.io/fsi-customer  =
echo =                                                                     =
echo =  Documentation can be found in 'docs' directory.                    =
echo =                                                                     =
echo =  Note: it takes a few minutes to expose these services...           =
echo =                                                                     =
echo =======================================================================
echo.
GOTO :EOF
      

:validateIP ipAddress [returnVariable]

    setlocal 

    set "_return=1"

    echo %~1^| findstr /b /e /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul

    if not errorlevel 1 for /f "tokens=1-4 delims=." %%a in ("%~1") do (
        if %%a gtr 0 if %%a lss 255 if %%b leq 255 if %%c leq 255 if %%d gtr 0 if %%d leq 254 set "_return=0"
    )

:endValidateIP

    endlocal & ( if not "%~2"=="" set "%~2=%_return%" ) & exit /b %_return%
	
:printDocs
  echo This project can be installed on any OpenShift platform. It's possible to
  echo install it on any available installation by pointing this installer to an
  echo OpenShift IP address:
  echo.
  echo   $ ./init.sh IP
  echo.
  echo If using Red Hat OCP, IP should look like: 192.168.99.100
  echo.
