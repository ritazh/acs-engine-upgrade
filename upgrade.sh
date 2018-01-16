#!/bin/bash
#
echo $(date +"%F %T%z") "starting script upgrade.sh"
CURRENT_VERSION=$1
TARGET_VERSION=$2
echo "CURRENT_VERSION: $CURRENT_VERSION"
echo "TARGET_VERSION: $TARGET_VERSION"

if [ -z "$CURRENT_VERSION" ]; then
  echo "Error: Missing parameter for current version. Example: 'sudo bash upgrade.sh 1.6.12 1.7.7'"
  exit 0
fi
if [ -z "$TARGET_VERSION" ]; then
  echo "Error: Missing parameter for target version. Example: 'sudo bash upgrade.sh 1.6.12 1.7.7'"
  exit 0
fi

SCRIPT_URL="https://raw.githubusercontent.com/ritazh/acs-engine-upgrade/fix-script/acsengine-upgrade.sh"
SSH_KEY="id_rsa"
NODES="k8s-agentpool[1-9]-[0-9]*-[0-9]"

echo "Upgrading kubectl on master..." && \
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
chmod +x ./kubectl && \
mv ./kubectl /usr/local/bin/kubectl && \
echo "Upgrading kubelet and manifests..." && \
grep -rl hyperkube-amd64:v$CURRENT_VERSION /etc/kubernetes | xargs sed -i "s@hyperkube-amd64:v$CURRENT_VERSION@hyperkube-amd64:v$TARGET_VERSION@g"
curl -LOk $SCRIPT_URL && sudo bash acsengine-upgrade.sh $CURRENT_VERSION $TARGET_VERSION

nodes=$(kubectl get node -o name | grep -o $NODES)

for node in $nodes; do
    echo "Cordoning $node..." && kubectl cordon $node
done

for node in $nodes; do
    echo "Draining $node...$logname" && kubectl drain $node --ignore-daemonsets && \
    ssh -l $(logname) -i /home/$(logname)/.ssh/$SSH_KEY -t -oStrictHostKeyChecking=no $node "echo 'Working on $node...' && curl -LOk $SCRIPT_URL && sudo bash acsengine-upgrade.sh $CURRENT_VERSION $TARGET_VERSION"
done

for node in $nodes; do
    echo "Uncordoning $node..." && kubectl uncordon $node
done

echo "Upgrade complete!"
