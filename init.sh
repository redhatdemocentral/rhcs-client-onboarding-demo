#!/bin/sh 
DEMO="Cloud Client Onboarding Demo"
AUTHORS="Duncan Doyle, Entando, Andrew Block, Eric D. Schabell"
PROJECT="git@github.com:redhatdemocentral/rhcs-client-onboarding-demo.git"

# Adjust these variables to point to an OCP instance.
OPENSHIFT_USER=openshift-dev
OPENSHIFT_PWD=devel
HOST_IP=yourhost.com
TEMPLATES=support/templates
OCP_DESCRIPTION="Client Onboarding"
OCP_PRJ=client-onboarding
GIT_URI=https://github.com/redhatdemocentral/fsi-onboarding-bpm.git
FSI_CUSTOMER_REPO=https://github.com/redhatdemocentral/fsi-customer.git
FSI_BACKOFFICE_REPO=https://github.com/redhatdemocentral/fsi-backoffice.git

# prints the documentation for this script.
function print_docs() 
{
	echo "This project can be installed on any OpenShift platform, such as the OpenShift Container"
  echo "Platform (OCP). It is possible to install it on any available installation, just point"
  echo "this installer at your installation by passing an IP of your OpenShift installation:"
	echo
	echo "   $ ./init.sh IP"
	echo
	echo "If using Red Hat OCP, IP should look like: 192.168.99.100"
	echo
}

# check for a valid passed IP address.
function valid_ip()
{
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi

	return $stat
}

# wipe screen.
clear 

echo
echo "########################################################################"
echo "##                                                                    ##"   
echo "##  Setting up the ${DEMO}                       ##"
echo "##                                                                    ##"   
echo "##                                                                    ##"   
echo "##     ####  ####   #   #      ### #   # ##### ##### #####            ##"
echo "##     #   # #   # # # # #    #    #   #   #     #   #                ##"
echo "##     ####  ####  #  #  #     ##  #   #   #     #   ###              ##"
echo "##     #   # #     #     #       # #   #   #     #   #                ##"
echo "##     ####  #     #     #    ###  ##### #####   #   #####            ##"
echo "##                                                                    ##" 
echo "##             #### #      ###  #   # ####                            ##"
echo "##        #   #     #     #   # #   # #   #                           ##"
echo "##       ###  #     #     #   # #   # #   #                           ##"
echo "##        #   #     #     #   # #   # #   #                           ##"
echo "##             #### #####  ###   ###  ####                            ##"
echo "##                                                                    ##"   
echo "##  brought to you by,                                                ##"   
echo "##     ${AUTHORS}          ##"
echo "##                                                                    ##"   
echo "##  ${PROJECT}  ##"
echo "##                                                                    ##"   
echo "########################################################################"
echo

# validate OpenShift host IP.
if [ $# -eq 1 ]; then
	if valid_ip "$1" || [ "$1" == "$HOST_IP" ]; then
		echo "OpenShift host given is a valid IP..."
		HOST_IP=$1
		echo
		echo "Proceeding with OpenShift host: $HOST_IP..."
		echo
	else
		# bad argument passed.
		echo "Please provide a valid IP that points to an OpenShift installation..."
		echo
		print_docs
		echo
		exit
	fi
elif [ $# -gt 1 ]; then
	print_docs
	echo
	exit
else
	# no arguments, prodeed with default host.
	print_docs
	echo
	exit
fi

# make some checks first before proceeding.	
command -v oc -v >/dev/null 2>&1 || { echo >&2 "OpenShift command line tooling is required but not installed yet... download here:
https://access.redhat.com/downloads/content/290"; exit 1; }

echo "OpenShift commandline tooling is installed..."
echo 
echo "Logging in to OpenShift as $OPENSHIFT_USER..."
echo
oc login $HOST_IP:8443 --password=$OPENSHIFT_PWD --username=$OPENSHIFT_USER

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred during 'oc login' command!"
	exit
fi
						
echo "Installing client onboarding process driven applicaiton..."
echo
echo "Creating $OCP_PRJ project..."
echo
oc new-project "$OCP_PRJ" --display-name="$OCP_DESCRIPTION" --description="Process driven client onboarding application scenario." 

echo
echo "Creating secrets and service accounts..."
echo
oc process -f $TEMPLATES/secrets-and-accounts.yaml | oc create -f -

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred during setup secrets and service accounts!"
	exit
fi

echo
echo "Adding policies to service accounts..."
echo
oc policy add-role-to-user view system:serviceaccount:$OCP_PRJ:processserver-service-account

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred adding policies to service accounts!"
	exit
fi

echo
echo "Creating Client Onboarding Build and Deployment config..."
echo
oc process -f $TEMPLATES/client-onboarding-process.yaml -p GIT_URI="$GIT_URI" -p GIT_REF="master" -n $OCP_PRJ | oc create -f - -n $OCP_PRJ

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred creating client onboarding build and deployment config!" 
	exit
fi

echo
echo "Creating new app for fsi-customer..."
echo
oc new-app "$FSI_CUSTOMER_REPO" --name fsi-customer

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred during new app creation for fsi-customer!" 
	exit
fi

echo
echo "Exposing fsi-customer service..."
echo
oc expose svc fsi-customer --name=entando-fsi-customer

if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred during exposure of fsi-customer service!"
	exit
fi

echo
echo "Creating new app for fsi-backoffice..."
echo
oc new-app "$FSI_BACKOFFICE_REPO" --name fsi-backoffice

echo
echo "Exposing fsi-backoffice service..."
echo
oc expose svc fsi-backoffice --name=entando-fsi-backoffice
																					
if [ "$?" -ne "0" ]; then
	echo
	echo "Error occurred during exposure of fsi-backoffice service!"
	exit
fi

echo
echo "========================================================================"
echo "=                                                                     ="
echo "=  Login to start exploring the Client Oboarding application:         ="
echo "=                                                                     ="
echo "=  http://entando-fsi-backoffice-$OCP_PRJ.$HOST_IP.nip.io/fsi-backoffice ="
echo "=                                                                     ="
echo "=       [ u:account / p:adminadmin ]                                  ="
echo "=       [ u:knowledge / p:adminadmin ]                                ="
echo "=       [ u:legal / p:adminadmin ]                                    ="
echo "=       [ u:Manager / p:adminadmin ]                                  ="
echo "=                                                                     ="
echo "=  http://entando-fsi-customer-$OCP_PRJ.$HOST_IP.nip.io/fsi-customer  ="
echo "=                                                                     ="
echo "=  Documentation can be found in 'docs' directory.                    ="
echo "=                                                                     ="
echo "=  Note: it takes a few minutes to expose these services...           ="
echo "=                                                                     ="
echo "======================================================================="
echo

