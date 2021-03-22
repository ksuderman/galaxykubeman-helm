#!/usr/bin/env bash
PREFIX=keith-rel-test
helm install -n $PREFIX $PREFIX-dev . \
#    --set galaxy.image.tag=21.01 \
    --set galaxy.terra.launch.workspace="De novo transcriptome reconstruction with RNA-Seq"\
    --set galaxy.terra.launch.namespace="galaxy-anvil"\
    --set cvmfs.cache.preload.enabled=false\
    --set galaxy.configs."galaxy\.yml".galaxy.single_user="suderman@jhu.edu"\
    --set galaxy.configs."galaxy\.yml".galaxy.admin_users="suderman@jhu.edu"\
    --set galaxy.metrics.enabled=false \
    --set persistence.nfs.persistentVolume.extraSpec.gcePersistentDisk.pdName="$PREFIX-nfs-pd"\
    --set persistence.nfs.size="250Gi" \
    --set persistence.postgres.name="$PREFIX-postgres-disk" \
    --set persistence.postgres.persistentVolume.extraSpec.gcePersistentDisk.pdName="$PREFIX-postgres-pd" \
    --set persistence.postgres.size="10Gi"\
    --set nfs.persistence.existingClaim="$PREFIX-nfs-disk-pvc" \
    --set nfs.persistence.size="250Gi" \
    --set galaxy.postgresql.persistence.existingClaim="$PREFIX-postgres-disk-pvc" \
    --set galaxy.persistence.size="200Gi"
    
