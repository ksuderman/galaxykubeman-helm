#!/usr/bin/env bash
set -eu

GKE_VERSION=1.18.12-gke.1210
GKE_ZONE=us-east1-b

# Default settings for the common parameters
#MACHINE=n1-standard-4
MACHINE=n1-highmem-8
PREFIX=keith-rel-test
IMAGE=galaxy/galaxy-anvil
TAG=21.01-auto
AUTO_SCALE=false
MIN_NODES=1
MAX_NODES=1
#KUBEMAN_REPO=anvil/galaxykubeman
KUBEMAN_REPO=.
# ANSI color codes for the console.
reset="\033[0m"
bold="\033[1m"
ital="\033[3m" # does not work on OS X

# Function used to highlight text.
function hi() {
    echo -e "$bold$@$reset"
}

function help() {
    cat | less -R << EOF

$(hi USAGE)
   ./anvil.sh [--settings FILE] [--tag TAG] [--prefix PREFIX] [--auto MIN MAX] (cluster|disks|namespace|helm|all|cleanup)

$(hi SYNOPSIS)
    Provisions an Anvil cluster on GKE

$(hi COMMANDS)
    $(hi cluster)   provisions the nodes on GCE
    $(hi disks)     provisions disks for persistent storage
    $(hi namespace) declares the namespace using the \$PREFIX variable
    $(hi helm)      runs helm to install Galaxy
    $(hi all)       does all of the above
    $(hi help)      displays this help message
    $(hi cleanup)   !!!  deletes the clusters AND the disks  !!!

$(hi OPTIONS)
    $(hi -s|--settings) sources variables from a settings file
    $(hi -p|--prefix)   sets the PREFIX variable
    $(hi -t|--tag)      sets the Docker TAG
    $(hi -a|--auto)     enables and autoscaling cluster and sets the min and max nodes

$(hi EXAMPLES)
    $(hi \$\>) ./anvil.sh cluster disk helm
    $(hi \$\>) ./anvil.sh --settings 2105.sh all
    $(hi \$\>) ./anvil.sh --settings 2105.sh --as 1 4 all
    $(hi \$\>) ./anvil.sh --prefix anvil-production cleanup

EOF
}

if [[ $# == 0 ]] ; then
	help
	exit
fi

function cluster() {
	echo "Provisioning cluster"
	if [[ $AUTO_SCALE = true ]] ; then
		gcloud container clusters create $PREFIX-cluster --cluster-version=$GKE_VERSION --disk-size=100 --num-nodes=1 --machine-type=$MACHINE --zone $GKE_ZONE --enable-autoscaling --min-nodes $MIN_NODES --max-nodes $MAX_NODES
	else
		gcloud container clusters create $PREFIX-cluster --cluster-version=$GKE_VERSION --disk-size=100 --num-nodes=1 --machine-type=$MACHINE --zone $GKE_ZONE
	fi
}

function disks() {
	echo "Creating disks"
	gcloud compute disks create "$PREFIX-postgres-pd" --size 10Gi --zone us-east1-b
	gcloud compute disks create "$PREFIX-nfs-pd" --size 250Gi --zone us-east1-b
}

function namespace() {
	echo "Declaring the $PREFIX namespace"
	kubectl create ns $PREFIX
}

function _helm() {
  local NAME="$PREFIX-galaxy"
	echo "Helm installing $NAME into namespace $PREFIX"
	helm install -n $PREFIX $NAME $KUBEMAN_REPO --version 0.8.0\
    --wait\
    --timeout 900s\
    --set nfs.storageClass.name="nfs-$PREFIX" \
    --set cvmfs.repositories.cvmfs-gxy-data-$PREFIX="data.galaxyproject.org" \
    --set cvmfs.repositories.cvmfs-gxy-main-$PREFIX="main.galaxyproject.org" \
    --set cvmfs.cache.alienCache.storageClass="nfs-$PREFIX" \
    --set galaxy.persistence.storageClass="nfs-$PREFIX" \
    --set galaxy.cvmfs.data.pvc.storageClassName=cvmfs-gxy-data-$PREFIX \
    --set galaxy.cvmfs.main.pvc.storageClassName=cvmfs-gxy-main-$PREFIX \
    --set galaxy.service.type=LoadBalancer \
    --set rbac.enabled=false\
    --set galaxy.image.repository=$IMAGE \
    --set galaxy.image.tag=$TAG \
    --set galaxy.terra.launch.workspace="De novo transcriptome reconstruction with RNA-Seq"\
    --set galaxy.terra.launch.namespace="galaxy-anvil"\
    --set cvmfs.cache.preload.enabled=false\
    --set galaxy.configs."galaxy\.yml".galaxy.single_user="suderman@jhu.edu"\
    --set galaxy.configs."galaxy\.yml".galaxy.admin_users="suderman@jhu.edu"\
    --set persistence.nfs.name="$PREFIX-nfs-disk"\
    --set persistence.nfs.persistentVolume.extraSpec.gcePersistentDisk.pdName="$PREFIX-nfs-pd"\
    --set persistence.nfs.size="250Gi" \
    --set persistence.postgres.name="$PREFIX-postgres-disk" \
    --set persistence.postgres.persistentVolume.extraSpec.gcePersistentDisk.pdName="$PREFIX-postgres-pd" \
    --set persistence.postgres.size="10Gi"\
    --set nfs.persistence.existingClaim="$PREFIX-nfs-disk-pvc" \
    --set nfs.persistence.size="250Gi" \
    --set galaxy.postgresql.persistence.existingClaim="$PREFIX-postgres-disk-pvc" \
    --set galaxy.persistence.size="200Gi"

}

function all() {
	cluster
	disks
	namespace
	_helm
}

function cleanup() {
	gcloud container clusters delete -q $PREFIX-cluster --zone $GKE_ZONE;
	gcloud compute disks delete -q "$PREFIX-postgres-pd" --zone $GKE_ZONE;
	gcloud compute disks delete -q "$PREFIX-nfs-pd" --zone $GKE_ZONE;

}

# Save command line arguments so we can shift through them twice; once to check
# that all commands are valid, and a second time to run the commands.
saved=$@

# Check the command line arguments.  Set any variables defined, but don't
# execute anything yet.
while [[ $# -gt 0 ]] ; do
	case $1 in
		cluster|disks|namespace|helm|all|cleanup) ;;
		-s|--settings)
			shift
			if [[ ! -e $1 ]] ; then
				echo "$(hi ERROR:) unable to find the settings file $1"
				exit 1
			fi
			source $1
			;;
		-t|--tag)
			shift
			TAG=$1
			;;
		-p|--prefix)
			shift
			PREFIX=$1
			;;
		-a|--as|--scale|--auto)
			shift
			AUTO_SCALE=true
			MIN_NODES=$1
			MAX_NODES=$2
			shift
			;;
		help)
			help
			exit
			;;
		*)
			echo "$(hi ERROR:) unrecognized option $1"
			exit 1
			;;
	esac
	shift
done

echo "PREFIX: $PREFIX"
echo "IMAGE : $IMAGE"
echo "TAG   : $TAG"

# Restore the command line parameters and run through them again running the
# commands and ignoring anything else.
set -- $saved
while [[ $# -gt 0 ]] ; do
	case $1 in
		cluster|disks|namespace|all|cleanup)
		    $1
		    ;;
		--settings|--tag|--prefix|-s|-t|-p|-a|--auto|--scale|--as)
			shift
			;;
		helm)
			_helm
			;;
		*)
			echo "$(hi ERROR:) unrecognized option $1"
			exit
			;;
	esac
	shift
done

echo "Done"
