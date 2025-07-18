#!/bin/bash

set -e
START_TS=$(date +%s)
SINV="${0} ${@}"
SDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


err() {
    echo; echo;
    echo -e "\e[97m\e[101m[ERROR]\e[0m ${1}"; shift; echo;
    while [[ $# -gt 0 ]]; do echo "    $1"; shift; done
    echo; exit 1;
}

# Checking if we are root
test "$(whoami)" = "root" || err "Not running as root"

# Process Arguments
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -O|--okd-version)
    OKD_VERSION="$2"
    shift
    shift
    ;;
    -R|--fcos-version|--coreos-version)
    FCOS_VERSION="$2"
    shift
    shift
    ;;
    -S|--fcos-stream)
    FCOS_STREAM="$2"
    shift
    shift
    ;;
    -F|--find-fcos|--find-scos|--find-coreos)
    FIND_COREOS="yes"
    shift
    shift
    ;;
    -m|--masters)
    N_MAST="$2"
    test "$N_MAST" -gt "0" &>/dev/null || err "Invalid masters: $N_MAST"
    shift
    shift
    ;;
    -w|--workers)
    N_WORK="$2"
    test "$N_WORK" -ge "0" &> /dev/null || err "Invalid workers: $N_WORK"
    shift
    shift
    ;;
    -p|--pull-secret)
    PULL_SEC_F="$2"
    shift
    shift
    ;;
    -n|--libvirt-network)
    VIR_NET="$2"
    shift
    shift
    ;;
    -N|--libvirt-oct)
    VIR_NET_OCT="$2"
    test "$VIR_NET_OCT" -gt "0" -a "$VIR_NET_OCT" -lt "255" || err "Invalid subnet octet $VIR_NET_OCT"
    shift
    shift
    ;;
    -c|--cluster-name)
    CLUSTER_NAME="$2"
    shift
    shift
    ;;
    -d|--cluster-domain)
    BASE_DOM="$2"
    shift
    shift
    ;;
    -t|--network-type)
    export NETWORK_TYPE="$2"
    shift
    shift
    ;;    
    -v|--vm-dir)
    VM_DIR="$2"
    shift
    shift
    ;;
    -z|--dns-dir)
    DNS_DIR="$2"
    shift
    shift
    ;;
    -s|--setup-dir)
    SETUP_DIR="$2"
    shift
    shift
    ;;
    -x|--cache-dir)
    CACHE_DIR="$2"; mkdir -p "$CACHE_DIR"
    shift
    shift
    ;;
    --master-cpu)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --master-cpu"
    MAS_CPU="$2"
    shift
    shift
    ;;
    --master-mem)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --master-mem"
    MAS_MEM="$2"
    shift
    shift
    ;;
    --worker-cpu)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --worker-cpu"
    WOR_CPU="$2"
    shift
    shift
    ;;
    --worker-mem)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --worker-mem"
    WOR_MEM="$2"
    shift
    shift
    ;;
    --bootstrap-cpu)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --bootstrap-cpu"
    BTS_CPU="$2"
    shift
    shift
    ;;
    --bootstrap-mem)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --bootstrap-mem"
    BTS_MEM="$2"
    shift
    shift
    ;;
    --lb-cpu)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --lb-cpu"
    LB_CPU="$2"
    shift
    shift
    ;;
    --lb-mem)
    test "$2" -gt "0" &>/dev/null || err "Invalid value $2 for --lb-mem"
    LB_MEM="$2"
    shift
    shift
    ;;
    --lb-disk-size)
    test "$2" -gt "9" &>/dev/null || err "Invalid value $2 for --lb-disk-size"
    LB_DISKSIZE="$2"
    shift
    shift
    ;;
    --disk-size)
    test "$2" -gt "19" &>/dev/null || err "Invalid value $2 for --disk-size"
    DISK_SIZE="$2"
    shift
    shift
    ;;
    -X|--fresh-download)
    FRESH_DOWN="yes"
    shift
    ;;
    -k|--keep-bootstrap)
    KEEP_BS="yes"
    shift
    ;;
    --autostart-vms)
    AUTOSTART_VMS="yes"
    shift
    ;;
    --destroy)
    CLEANUP="yes"
    shift
    ;;
    -y|--yes)
    YES="yes"
    shift
    ;;
    -h|--help)
    SHOW_HELP="yes"
    shift
    ;;
    *)
    echo "ERROR: Invalid argument $key"
    exit 1
    ;;
esac
done


if [ "$SHOW_HELP" == "yes" ]; then
echo
echo "Usage: ${0} [OPTIONS]"
echo
cat << EOF | column -t -s '|' -N OPTION,DESCRIPTION -W DESCRIPTION

-O, --okd-version VERSION|The OKD version to install.
|You can set this to a specific version like "4.15.0-0.okd-2024-03-10-010116" etc. More info on https://github.com/openshift/okd/releases.
|Default: 4.15.0-0.okd-2024-03-10-010116

-R, --fcos-version VERSION|You can set a specific FCOS version to use. For example "42.20250609.3.0" etc. More info on https://getfedora.org/coreos/download?tab=metal_virtualized&stream=stable.
|Default: 42.20250609.3.0

-p, --pull-secret FILE|Location of the pull secret file
|Default: /opt/pull-secret

-c, --cluster-name NAME|OKD 4 cluster name
|Default: OKD4

-d, --cluster-domain DOMAIN|OKD 4 cluster domain
|Default: local

-m, --masters N|Number of masters to deploy
|Default: 3

-w, --worker N|Number of workers to deploy
|Default: 2

--master-cpu N|Master VMs CPUs
|Default: 8

--master-mem SIZE(MB)|Master VMs Memory (in MB)
|Default: 16384

--worker-cpu N|Worker VMs CPUs
|Default: 4

--worker-mem SIZE(MB)|Worker VMs Memory (in MB)
|Default: 8192

--bootstrap-cpu N|Bootstrap VM CPUs
|Default: 8

--bootstrap-mem SIZE(MB)|Bootstrap VM Memory (in MB)
|Default: 16384

--lb-cpu N|Loadbalancer VM CPUs
|Default: 2

--bootstrap-mem SIZE(MB)|Loadbalancer VM Memory (in MB)
|Default: 3072

-n, --libvirt-network NETWORK|The libvirt network to use. Select this option if you want to use an existing libvirt network.
|The libvirt network should already exist. If you want the script to create a separate network for this installation see: -N, --libvirt-oct
|Default: default

-N, --libvirt-oct OCTET|You can specify a 192.168.{OCTET}.0 subnet octet and this script will create a new libvirt network for the cluster
|The network will be named okd-{OCTET}. If the libvirt network okd-{OCTET} already exists, it will be used.
|Default: <not set>

-v, --vm-dir|The location where you want to store the VM Disks
|Default: /var/lib/libvirt/images

-z, --dns-dir DIR|We expect the DNS on the host to be managed by dnsmasq. You can use NetworkMananger's built-in dnsmasq or use a separate dnsmasq running on the host. If you are running a separate dnsmasq on the host, set this to "/etc/dnsmasq.d"
|Default: /etc/NetworkManager/dnsmasq.d

-s, --setup-dir DIR|The location where we the script keeps all the files related to the installation
|Default: /opt/OKD4_setup_{CLUSTER_NAME}

-x, --cache-dir DIR|To avoid un-necessary downloads we download the OKD/CoreOS files to a cache directory and reuse the files if they exist
|This way you only download a file once and reuse them for future installs
|You can force the script to download a fresh copy by using -X, --fresh-download
|Default: /opt/OKD4_downloads

-X, --fresh-download|Set this if you want to force the script to download a fresh copy of the files instead of reusing the existing ones in cache dir
|Default: <not set>

-k, --keep-bootstrap|Set this if you want to keep the bootstrap VM. By default bootstrap VM is removed once the bootstraping is finished
|Default: <not set>

--autostart-vms|Set this if you want to the cluster VMs to be set to auto-start on reboot.
|Default: <not set>

-y, --yes|Set this for the script to be non-interactive and continue with out asking for confirmation
|Default: <not set>

--destroy|Set this if you want the script to destroy everything it has created.
|Use this option with the same options you used to install the cluster.
|Be carefull this deletes the VMs, DNS entries and the libvirt network (if created by the script)
|Default: <not set>
EOF
echo
echo "Examples:"
echo
echo "# Deploy OKD 4.19.0-okd-scos.6 cluster"
echo "${0} --okd-version 4.19.0-okd-scos.6"
echo "${0} -O 4.19.0-okd-scos.6"
echo 
echo "# Deploy OKD 4.20.0-okd-scos.ec.5 cluster with Fedora CoreOS 42.20250609.3.0"
echo "${0} --okd-version 4.20.0-okd-scos.ec.5 --fcos-version 42.20250609.3.0"
echo "${0} -O 4.20.0-okd-scos.ec.5 -R 42.20250609.3.0"
echo 
echo "# Deploy OKD 4.15.0-0.okd-2024-03-10-010116 with custom cluster name and domain"
echo "${0} --cluster-name OKD45 --cluster-domain lab.test.com --okd-version 4.15.0-0.okd-2024-03-10-010116"
echo "${0} -c OKD45 -d lab.test.com -O 4.15.0-0.okd-2024-03-10-010116"
echo
echo "# Deploy OKD 4.15.0-0.okd-2024-03-10-010116 on new libvirt network (192.168.155.0/24)"
echo "${0} --okd-version 4.15.0-0.okd-2024-03-10-010116 --libvirt-oct 155"
echo "${0} -O 4.15.0-0.okd-2024-03-10-010116 -N 155"
echo 
echo "# Destory the already installed cluster"
echo "${0} --cluster-name OKD45 --cluster-domain lab.test.com --destroy-installation"
echo "${0} -c OKD45 -d lab.test.com --destroy-installation"
echo
exit
fi

# Default Values
test -z "$OKD_VERSION" && OKD_VERSION="4.15.0-0.okd-2024-03-10-010116"
test -z "$FCOS_VERSION" && FCOS_VERSION="39.20240210.3.0"
test -z "$FCOS_STREAM" && FCOS_STREAM="stable"
test -z "$FIND_COREOS" && FIND_COREOS="no"
test -z "$N_MAST" && N_MAST="2"
test -z "$N_WORK" && N_WORK="3"
test -z "$MAS_CPU" && MAS_CPU="8"
test -z "$MAS_MEM" && MAS_MEM="16384"
test -z "$WOR_CPU" && WOR_CPU="4"
test -z "$WOR_MEM" && WOR_MEM="8192"
test -z "$BTS_CPU" && BTS_CPU="8"
test -z "$BTS_MEM" && BTS_MEM="16384"
test -z "$LB_CPU" && LB_CPU="2"
test -z "$LB_MEM" && LB_MEM="3072"
test -z "$LB_DISKSIZE" && LB_DISKSIZE="10"
test -z "$DISK_SIZE" && DISK_SIZE="50"
test -z "$VIR_NET" -a -z "$VIR_NET_OCT" && VIR_NET="default"
test -n "$VIR_NET" -a -n "$VIR_NET_OCT" && err "Specify either -n or -N" 
test -z "$CLUSTER_NAME" && CLUSTER_NAME="okd4"
test -z "$BASE_DOM" && BASE_DOM="local"
test -z "$NETWORK_TYPE" && NETWORK_TYPE="OVNKubernetes"
test -z "$DNS_DIR" && DNS_DIR="/etc/NetworkManager/dnsmasq.d"
test -z "$VM_DIR" && VM_DIR="/opt/libvirt/images"
test -z "$FRESH_DOWN" && FRESH_DOWN="no"
test -z "$SETUP_DIR" && SETUP_DIR="/opt/OKD4_setup_${CLUSTER_NAME}"
test -z "$CACHE_DIR" && CACHE_DIR="/opt/OKD4_downloads" && mkdir -p "$CACHE_DIR"
test -z "$PULL_SEC_F" && PULL_SEC_F="/opt/pull-secret"; PULL_SEC=$(cat "$PULL_SEC_F")

OKD_MIRROR="https://github.com/openshift/okd/releases/download"
FCOS_MIRROR="https://builds.coreos.fedoraproject.org/prod/streams/$FCOS_STREAM/builds"

LB_IMG_URL="https://raw.repo.almalinux.org/almalinux/10.0/cloud/x86_64_v2/images/AlmaLinux-10-GenericCloud-latest.x86_64_v2.qcow2"

ok() {
    test -z "$1" && echo "ok" || echo "$1"
}

check_if_we_can_continue() {
    if [ "$YES" != "yes" ]; then
        echo;
        test -n "$1" && echo "[NOTE] $1"
        echo -n "Press enter to continue"; read x;
    fi
}

download() {
    if [ "$1" == "check" ]; then
        if [ -f "${CACHE_DIR}/$2" ]; then
            if [ "$FRESH_DOWN" = "yes" ]; then
                echo "(cached file found, but will be removed due to fresh download)"
            else
                echo "(reusing cached file) "
            fi
        else
            if curl -qs --head --fail "$3" &> /dev/null; then
                echo
            else
                err "$3 not reachable"
            fi
        fi
    elif [ "$1" == "get" ] && [ -n "$2" ]; then
        if [ "$FRESH_DOWN" = "yes" ] && [ -f "${CACHE_DIR}/$2" ]; then
            rm -f "${CACHE_DIR}/$2"
        fi
        if [ -f "${CACHE_DIR}/$2" ]; then
            echo "(reusing cached file) "
        else
            echo
            wget "$3" -O "${CACHE_DIR}/$2"
        fi
    fi
}

echo
echo "##########################################"
echo "########### CPUs and RAM CHECK ###########"
echo "##########################################"
echo

AVAILABLE_CPUS=$(lscpu | grep '^CPU(s)' | cut -f2 -d':' | tr -d ' ' | head -1)
AVAILABLE_RAM_INKB=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
AVAILABLE_RAM=$(( AVAILABLE_RAM_INKB / 1024 ))
REQUESTED_RAM=$(( N_MAST * MAS_MEM + N_WORK * WOR_MEM + BTS_MEM + LB_MEM ))
REQUESTED_CPUS=$(( N_MAST * MAS_CPU + N_WORK * WOR_CPU + BTS_CPU + LB_CPU ))

# Convert to GB
REQUESTED_GB=$(( REQUESTED_RAM / 1024 ))
AVAILABLE_GB=$(( AVAILABLE_RAM / 1024 ))
SAFE_RAM_LIMIT=$(( AVAILABLE_RAM * 3 / 2 ))  # 50% overcommitment
SAFE_RAM_LIMIT_GB=$(( SAFE_RAM_LIMIT / 1024 ))

WARNING_LIMIT=$(( AVAILABLE_CPUS * 5 ))
ERROR_LIMIT=$(( AVAILABLE_CPUS * 10 ))

# CPU Check with maximum 1000% overcommitment
printf "====> Checking available CPUs : "
if [ "$REQUESTED_CPUS" -ge "$ERROR_LIMIT" ]; then
    err "Requested CPUs: $REQUESTED_CPUS / $AVAILABLE_CPUS (it's more than 1000% overcommitment!)"
elif [ "$REQUESTED_CPUS" -ge "$WARNING_LIMIT" ]; then
    echo "[WARNING] Requested CPUs: $REQUESTED_CPUS / $AVAILABLE_CPUS (fit in the 500% overcommitment)"
elif [ "$REQUESTED_CPUS" -le "$AVAILABLE_CPUS" ]; then
    echo "OK (all vCPUs fit in physical CPUs: $REQUESTED_CPUS / $AVAILABLE_CPUS)"
else
    echo "OK (overcommitment, but within safe 500% limit: $REQUESTED_CPUS / $AVAILABLE_CPUS)"
fi

# 50% Memory Overcommitment allowed
printf "====> Checking available RAM : "
if [ "$REQUESTED_RAM" -le "$AVAILABLE_RAM" ]; then
    echo "OK (requested RAM: ${REQUESTED_GB}GB, available: ${AVAILABLE_GB}GB)"
elif [ "$REQUESTED_RAM" -le "$SAFE_RAM_LIMIT" ]; then
    echo "[WARNING] Requested RAM: ${REQUESTED_GB}GB, available: ${AVAILABLE_GB}GB (fits within 50% overcommitment, safe limit: ${SAFE_RAM_LIMIT_GB}GB)"
else
    err "Requested RAM: ${REQUESTED_GB}GB exceeds 50% overcommitment safe limit (${SAFE_RAM_LIMIT_GB}GB)"
fi


if [ "$CLEANUP" == "yes" ]; then

    echo 
    echo "##################"
    echo "####  DESTROY  ###"
    echo "##################"
    echo 

    if [ -f /tmp/bootstrap.iso ]; then rm -rf /tmp/bootstrap.iso; fi
    if [ -f /tmp/master.iso ]; then rm -rf /tmp/master.iso; fi
    if [ -f /tmp/worker.iso ]; then rm -rf /tmp/worker.iso; fi
    if [ -d /tmp/bootstrap_ign ]; then rm -rf /tmp/bootstrap_ign; fi
    if [ -d /tmp/master_ign ]; then rm -rf /tmp/master_ign; fi
    if [ -d /tmp/worker_ign ]; then rm -rf /tmp/worker_ign; fi

    if [ -n "$VIR_NET_OCT" -a -z "$VIR_NET" ]; then
        VIR_NET="okd-${VIR_NET_OCT}"
    fi

    for vm in $(virsh list --all --name | grep "${CLUSTER_NAME}-lb\|${CLUSTER_NAME}-master-\|${CLUSTER_NAME}-worker-\|${CLUSTER_NAME}-bootstrap"); do
        check_if_we_can_continue "Deleting VM $vm"
        IP=$(virsh domifaddr "$vm" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
        MAC=$(virsh domifaddr "$vm" | grep ipv4 | head -n1 | awk '{print $2}')
        echo -n "XXXX> Deleting DHCP reservation for VM $vm: "
        virsh net-update ${VIR_NET} delete ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config > /dev/null || true ||\
        err "Deleting DHCP reservation failed"; ok
        echo -n "XXXX> Deleting VM $vm: "
        if ! virsh destroy "$vm" > /dev/null 2>&1; then
            echo "virsh destroy $vm failed, trying undefine..."
        fi
        if ! virsh undefine "$vm" --remove-all-storage > /dev/null 2>&1; then
            err "virsh undefine $vm --remove-all-storage failed"
        fi
        ok
    done

    if [ -n "$VIR_NET_OCT" ]; then
        virsh net-uuid "okd-${VIR_NET_OCT}" &> /dev/null
        if [ "$?" == "0" ]; then
            check_if_we_can_continue "Deleting libvirt network okd-${VIR_NET_OCT}"
            echo -n "XXXX> Deleting libvirt network okd-${VIR_NET_OCT}: "
            virsh net-destroy "okd-${VIR_NET_OCT}" > /dev/null || err "virsh net-destroy okd-${VIR_NET_OCT} failed"
            virsh net-undefine "okd-${VIR_NET_OCT}" > /dev/null || err "virsh net-undefine okd-${VIR_NET_OCT} failed"
            ok
        fi
    fi

    if [ -d "$SETUP_DIR" ]; then
        check_if_we_can_continue "Removing directory (rm -rf) $SETUP_DIR"
        echo -n "XXXX> Deleting (rm -rf) directory $SETUP_DIR: "
        rm -rf "$SETUP_DIR"
        ok
    fi

    cat /etc/hosts | grep -v "^#" | grep -q -s "${CLUSTER_NAME}\.${BASE_DOM}$" > /dev/null
    if [ "$?" == "0" ]; then
        check_if_we_can_continue "Commenting entries in /etc/hosts for ${CLUSTER_NAME}.${BASE_DOM}"
        echo -n "XXXX> Commenting entries in /etc/hosts for ${CLUSTER_NAME}.${BASE_DOM}: "
        sed -i "s/\(.*\.${CLUSTER_NAME}\.${BASE_DOM}$\)/#\1/" "/etc/hosts" || err "sed failed"
        ok
    fi

    if [ -f "${DNS_DIR}/${CLUSTER_NAME}.conf" ]; then
        check_if_we_can_continue "Removing file ${DNS_DIR}/${CLUSTER_NAME}.conf"
        echo -n "XXXX> Removing file ${DNS_DIR}/${CLUSTER_NAME}.conf: "
        rm -f "${DNS_DIR}/${CLUSTER_NAME}.conf" &> /dev/null || true 
        ok
    fi

    exit
fi



echo 
echo "##########################################"
echo "### OKD/CoreOS VERSION/URL CHECK  ###"
echo "##########################################"
echo

echo -n "====> Looking up OKD4 client for release $OKD_VERSION: "
CLIENT="openshift-client-linux-${OKD_VERSION}.tar.gz"; ok "$CLIENT"
CLIENT_URL="${OKD_MIRROR}/${OKD_VERSION}/${CLIENT}"
echo "====> ${CLIENT_URL}"
echo -n "====> Checking if Client URL is downloadable: "; download check "$CLIENT" "$CLIENT_URL";

echo -n "====> Looking up OKD4 installer for release $OKD_VERSION: "
INSTALLER="openshift-install-linux-${OKD_VERSION}.tar.gz"; ok "$INSTALLER"
INSTALLER_URL="${OKD_MIRROR}/${OKD_VERSION}/${INSTALLER}"
echo "====> ${INSTALLER_URL}"
echo -n "====> Checking if Installer URL is downloadable: ";  download check "$INSTALLER" "$INSTALLER_URL";

if [[ "${FIND_COREOS}" == "yes" ]]; then
  echo "====> Discovering CoreOS image via openshift-install selected"
  echo "====> Can't list version now..."
else
  echo "====> Looking up CoreOS QEMU image for release ${FCOS_VERSION}"
  IMAGE="fedora-coreos-${FCOS_VERSION}-qemu.x86_64.qcow2.xz"
  IMAGE_URL="${FCOS_MIRROR}/${FCOS_VERSION}/x86_64/${IMAGE}"
  echo "====> Image filename: ${IMAGE}"
  echo "====> Image URL:      ${IMAGE_URL}"
  echo -n "====> Checking if Image URL is downloadable: "; download check "${IMAGE}" "${IMAGE_URL}"
fi

# AlmaLinux CLOUD IMAGE
LB_IMG="${LB_IMG_URL##*/}"
echo "====> ${LB_IMG_URL}"
echo -n "====> Checking if AlmaLinux cloud image URL is downloadable: "; download check "$LB_IMG" "$LB_IMG_URL";

echo
echo
echo "      OKD Version = $OKD_VERSION"
echo
if [[ "${FIND_COREOS}" == "yes" ]]; then
echo "      CoreOS Version will be defined automatically later..."
else
echo "      CoreOS Version = $FCOS_VERSION"
echo "      CoreOS Stream = $FCOS_STREAM"
echo
fi

check_if_we_can_continue

echo 
echo "###################################" 
echo "### PRELIMINARY / SANITY CHECKS ###"
echo "###################################"
echo 


echo -n "====> Checking if we have all the dependencies: "
for x in virsh virt-install virt-customize systemctl dig wget
do
    builtin type -P $x &> /dev/null || err "executable $x not found"
done

# Libvirt network driver check for Debian based Linux disto too not only Redhat 
DRIVER1="/usr/lib64/libvirt/connection-driver/libvirt_driver_network.so"
DRIVER2="/usr/lib/x86_64-linux-gnu/libvirt/connection-driver/libvirt_driver_network.so"
DEFAULT_NET="/usr/share/libvirt/networks/default.xml"

if ! [ -e "$DRIVER1" ] && ! [ -e "$DRIVER2" ]; then
    err "file $DRIVER1 or $DRIVER2 not found"
fi

test -e "$DEFAULT_NET" &> /dev/null || err "file $DEFAULT_NET not found"

ok

echo -n "====> Checking if the script/working directory already exists: "
test -d "$SETUP_DIR" && \
    err "Directory $SETUP_DIR already exists" \
        "" \
        "You can use --destroy to remove your existing installation" \
        "You can also use --setup-dir to specify a different directory for this installation"
ok

echo -n "====> Checking if libvirt is running or enabled: "
    systemctl -q is-active libvirtd || systemctl -q is-enabled libvirtd || err "libvirtd is not running nor enabled"

echo -n "====> Checking libvirt network: "
if [ -n "$VIR_NET_OCT" ]; then
    virsh net-uuid "okd-${VIR_NET_OCT}" &> /dev/null && \
        {   VIR_NET="okd-${VIR_NET_OCT}"
            ok "re-using okd-${VIR_NET_OCT}"
            unset VIR_NET_OCT
        } || \
        {
            ok "will create okd-${VIR_NET_OCT} (192.168.${VIR_NET_OCT}.0/24)"
        }
elif [ -n "$VIR_NET" ]; then
    virsh net-uuid "${VIR_NET}" &> /dev/null || \
        err "${VIR_NET} doesn't exist"
    ok "using $VIR_NET"
else
    err "Sorry, unhandled situation. Exiting"
fi

echo -n "====> Checking if we have any existing leftover VMs: "
existing=$(virsh list --all --name | grep -m1 "${CLUSTER_NAME}-lb\|${CLUSTER_NAME}-master-\|${CLUSTER_NAME}-worker-\|${CLUSTER_NAME}-bootstrap") || true
test -z "$existing" || err "Found existing VM: $existing"
ok

echo -n "====> Checking for any existing leftover /etc/hosts records: "
existing=$(cat /etc/hosts | grep -v "^#" | grep -w -m1 "${CLUSTER_NAME}\.${BASE_DOM}") || true
test -z "$existing" || err "Found existing record in /etc/hosts: $existing" "(You can comment these out)"
ok

echo -n "====> Checking nameserver entries in resolv.conf: "
ok "$(grep "^nameserver " /etc/resolv.conf | awk '{print $2}'| tr '\n' ' ')"

echo -n "====> Checking if first entry in resolv.conf is pointing locally: "
test "$(grep -m1 "^nameserver " /etc/resolv.conf | awk '{print $2}')" = "127.0.0.1" \
    -o "$(grep "^nameserver " /etc/resolv.conf | awk '{print $2}'| wc -l)" == "1" \
    || err "First entry in /etc/resolv.conf not pointing to 127.0.0.1. \
    Ensure correct nameserver is present in /etc/resolv.conf along with 127.0.0.1 or package installation may fail. \
    Current list : $(grep "^nameserver " /etc/resolv.conf | awk '{print $2}'| tr '\n' ' ')"
ok

echo -n "====> Checking if DNS service (dnsmasq or NetworkManager) is active: "
if [ "$DNS_DIR" -ef "/etc/NetworkManager/dnsmasq.d" ]
then
    DNS_SVC="NetworkManager"; DNS_CMD="reload";
elif [ "$DNS_DIR" -ef "/etc/dnsmasq.d" ]
then
    DNS_SVC="dnsmasq"; DNS_CMD="restart";
else
    err "DNS_DIR (-z|--dns-dir), should be either /etc/dnsmasq.d or /etc/NetworkManager/dnsmasq.d"
fi
systemctl -q is-active $DNS_SVC || err "DNS_DIR points to $DNS_DIR but $DNS_SVC is not active"
ok

if [ "$DNS_DIR" -ef "/etc/NetworkManager/dnsmasq.d" ]
then
    echo -n "====> Checking if NetworkManager has entry for dnsmasq: "
    test "$(grep -R 'dns=dnsmasq' /etc/NetworkManager/* | awk -F: '{print $2}')" = 'dns=dnsmasq' || \
    err "dnsmasq is not enabled in NetworkManager. Please run below command. \necho -e '[main]\\\ndns=dnsmasq' > /etc/NetworkManager/conf.d/nm-dns.conf\nsystemctl restart NetworkManager"
    ok
fi

echo 
echo "#####################################################"
echo "### DOWNLOAD AND PREPARE OKD 4 INSTALLATION ###"
echo "#####################################################"
echo

if [ -n "$VIR_NET" ]; then
    virsh net-uuid "${VIR_NET}" &> /dev/null || \
        err "${VIR_NET} doesn't exist"
elif [ -n "$VIR_NET_OCT" ]; then
    if [ "$VIR_NET_RECREATE" == "yes" ]; then
        virsh net-uuid "okd-${VIR_NET_OCT}" &> /dev/null
        if [ "$?" == "0" ]; then
            check_if_we_can_continue "We will be deleting and recreating libvirt network okd-${VIR_NET_OCT}"
            echo -n "====> Deleting libvirt network okd-${VIR_NET_OCT}"
            virsh net-destroy "okd-${VIR_NET_OCT}" || \
                err "virsh net-destroy okd-${VIR_NET_OCT} failed"
            virsh net-undefine "okd-${VIR_NET_OCT}" || \
                err "virsh net-undefine okd-${VIR_NET_OCT} failed"
            ok
        fi
    fi
    echo -n "====> Creating libvirt network okd-${VIR_NET_OCT}"
    /usr/bin/cp /usr/share/libvirt/networks/default.xml /tmp/new-net.xml > /dev/null || err "Network creation failed"
    sed -i "s/default/okd-${VIR_NET_OCT}/" /tmp/new-net.xml
    sed -i "s/virbr0/okd-${VIR_NET_OCT}/" /tmp/new-net.xml
    sed -i "s/122/${VIR_NET_OCT}/g" /tmp/new-net.xml
    virsh net-define /tmp/new-net.xml > /dev/null || err "virsh net-define failed"
    virsh net-autostart okd-${VIR_NET_OCT} > /dev/null || err "virsh net-autostart failed"
    virsh net-start okd-${VIR_NET_OCT} > /dev/null || err "virsh net-start failed"
    systemctl restart libvirtd > /dev/null || err "systemctl restart libvirtd failed"
    echo "okd-${VIR_NET_OCT} created"
    VIR_NET="okd-${VIR_NET_OCT}"
else
    err "Sorry, unhandled situation. Exiting"
fi


echo -n "====> Creating and using directory $SETUP_DIR: "
mkdir -p $SETUP_DIR && cd $SETUP_DIR || err "using $SETUP_DIR failed"
ok

echo -n "====> Generating SSH key to be injected in all VMs: "
ssh-keygen -f sshkey -q -N "" || err "ssh-keygen failed"
SSH_KEY="sshkey.pub"; ok

echo -n "====> Downloading OCP Client: "; download get "$CLIENT" "$CLIENT_URL";
echo -n "====> Downloading OCP Installer: "; download get "$INSTALLER" "$INSTALLER_URL";
tar -xf "${CACHE_DIR}/${CLIENT}" && rm -f README.md
tar -xf "${CACHE_DIR}/${INSTALLER}" && rm -f rm -f README.md

# If $FIND_COREOS = yes define $IMAGE and $IMAGE_URL here
if [[ "${FIND_COREOS}" == "yes" ]]; then
  echo "====> Discovering CoreOS image via openshift-install"
  OC_INSTALL="${SETUP_DIR}/openshift-install"
  IMAGE_URL=$($OC_INSTALL coreos print-stream-json \
    | jq -r '.architectures.x86_64.artifacts.qemu.formats 
        | to_entries[]
        | select(.value.disk.location | test("qemu\\.x86_64"))
        | .value.disk.location')
  IMAGE=$(basename "${IMAGE_URL}")
  COREOS_VERSION="$(echo "${IMAGE}" | awk -F'-qemu' '{print $1}')"

  echo
  echo
  echo "      OKD Version = $OKD_VERSION"
  echo
  echo "      CoreOS Version = $COREOS_VERSION"
  echo

  echo "====> Image filename: ${IMAGE}"
  echo "====> Image URL:      ${IMAGE_URL}"
  echo -n "====> Checking if Image URL is downloadable: "; download check "${IMAGE}" "${IMAGE_URL}"
  check_if_we_can_continue
fi

echo -n "====> Downloading CoreOS Image: "; download get "$IMAGE" "$IMAGE_URL"

if [ ! -f "${CACHE_DIR}/${IMAGE%%.*}" ]; then
  echo "====> Unpacking QCOW2 image..."
  case "$IMAGE" in
    *.xz)
      unxz -k "${CACHE_DIR}/${IMAGE}" ;;
    *.gz)
      gunzip -f -k "${CACHE_DIR}/${IMAGE}" ;;
    *)
      echo "[WARN] Unknown compression format for ${IMAGE}, skipping unpack." ;;
  esac
fi

mkdir install_dir
cat <<EOF > install_dir/install-config.yaml
apiVersion: v1
baseDomain: ${BASE_DOM}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: ${N_MAST}
metadata:
  name: ${CLUSTER_NAME}
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: ${NETWORK_TYPE}
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '${PULL_SEC}'
sshKey: '$(cat $SSH_KEY)'
EOF


echo "====> Creating ignition configs: "
./openshift-install create ignition-configs --dir=$SETUP_DIR/install_dir || \
    err "./openshift-install create ignition-configs --dir=$SETUP_DIR/install_dir failed"

WS_PORT="1234"
cat <<EOF > tmpws.service
[Unit]
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt
ExecStart=/usr/bin/python3 -m http.server ${WS_PORT}
[Install]
WantedBy=default.target
EOF



cat > haproxy.cfg <<EOF
global
  log 127.0.0.1 local2
  chroot /var/lib/haproxy
  pidfile /var/run/haproxy.pid
  maxconn 4000
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats

defaults
  mode tcp
  log global
  option tcplog
  option dontlognull
  option redispatch
  retries 3
  timeout queue 1m
  timeout connect 10s
  timeout client 1m
  timeout server 1m
  timeout check 10s
  maxconn 3000

# 6443 points to control plane
frontend ${CLUSTER_NAME}-api
  bind *:6443
  default_backend master-api
backend master-api
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:6443 check
EOF

for i in $(seq 1 ${N_MAST}); do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:6443 check" >> haproxy.cfg
done

cat >> haproxy.cfg <<EOF

# 22623 points to control plane
frontend ${CLUSTER_NAME}-mapi
  bind *:22623
  default_backend master-mapi
backend master-mapi
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:22623 check
EOF

for i in $(seq 1 ${N_MAST}); do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:22623 check" >> haproxy.cfg
done

cat >> haproxy.cfg <<EOF

# 80 points to master nodes
frontend ${CLUSTER_NAME}-http
  bind *:80
  default_backend ingress-http
backend ingress-http
  balance source
EOF

for i in $(seq 1 ${N_MAST}); do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:80 check" >> haproxy.cfg
done

cat >> haproxy.cfg <<EOF

# 443 points to master nodes
frontend ${CLUSTER_NAME}-https
  bind *:443
  default_backend infra-https
backend infra-https
  balance source
EOF

for i in $(seq 1 ${N_MAST}); do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:443 check" >> haproxy.cfg
done



echo 
echo "#################################"
echo "### CREATING LOAD BALANCER VM ###"
echo "#################################"
echo

echo -n "====> Downloading AlmaLinux 10 cloud image: "; download get "$LB_IMG" "$LB_IMG_URL";

echo -n "====> Copying Image for Loadbalancer VM: "
cp "${CACHE_DIR}/${LB_IMG}" "${VM_DIR}/${CLUSTER_NAME}-lb.qcow2" || \
    err "Copying '${VM_DIR}/${LB_IMG}' to '${VM_DIR}/${CLUSTER_NAME}-lb.qcow2' failed"; ok
qemu-img resize -f qcow2 "${VM_DIR}/${CLUSTER_NAME}-lb.qcow2" "${LB_DISKSIZE}G"

echo "====> Setting up Loadbalancer VM: "
virt-customize -a "${VM_DIR}/${CLUSTER_NAME}-lb.qcow2" \
    --uninstall cloud-init --ssh-inject root:file:$SSH_KEY --selinux-relabel \
    --copy-in install_dir/bootstrap.ign:/opt/ \
    --copy-in install_dir/master.ign:/opt/ \
    --copy-in install_dir/worker.ign:/opt/ \
    --copy-in tmpws.service:/etc/systemd/system/ \
    --run-command "systemctl daemon-reload" \
    --run-command "systemctl enable tmpws.service" || \
    err "Setting up Loadbalancer VM image failed"

echo -n "====> Creating Loadbalancer VM: "
virt-install --import --name ${CLUSTER_NAME}-lb --disk "${VM_DIR}/${CLUSTER_NAME}-lb.qcow2" \
    --memory ${LB_MEM} --cpu host --vcpus ${LB_CPU} --os-variant almalinux9 \
    --network network=${VIR_NET},model=virtio --noreboot --noautoconsole > /dev/null || \
    err "Creating Loadbalancer VM failed"; ok

echo -n "====> Starting Loadbalancer VM "
virsh start ${CLUSTER_NAME}-lb > /dev/null || err "Starting Loadbalancer VM failed"; ok

echo -n "====> Waiting for Loadbalancer VM to obtain IP address: "
while true; do
    sleep 5
    LBIP=$(virsh domifaddr "${CLUSTER_NAME}-lb" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
    test "$?" -eq "0" -a -n "$LBIP"  && { echo "$LBIP"; break; }
done
MAC=$(virsh domifaddr "${CLUSTER_NAME}-lb" | grep ipv4 | head -n1 | awk '{print $2}')

echo -n "====> Adding DHCP reservation for LB IP/MAC: "
virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$LBIP'/>" --live --config &> /dev/null || \
    err "Adding DHCP reservation for $LBIP/$MAC failed"; ok

echo -n "====> Adding /etc/hosts entry for LB IP: "
    echo "$LBIP lb.${CLUSTER_NAME}.${BASE_DOM}" \
    "api.${CLUSTER_NAME}.${BASE_DOM}" \
    "api-int.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts; ok

echo -n "====> Waiting for SSH access on LB VM: "
ssh-keygen -R lb.${CLUSTER_NAME}.${BASE_DOM} &> /dev/null || true
ssh-keygen -R $LBIP  &> /dev/null || true
while true; do
    sleep 1
    ssh -i sshkey -o StrictHostKeyChecking=no lb.${CLUSTER_NAME}.${BASE_DOM} true &> /dev/null || continue
    break
done
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" true || err "SSH to lb.${CLUSTER_NAME}.${BASE_DOM} failed"; ok

# HAProxy Install and Confiure over SSH
echo "====> Installing haproxy, policycoreutils-python-utils and bind-utils on Loadbalancer VM: "
ssh -i sshkey lb.${CLUSTER_NAME}.${BASE_DOM} "dnf install -y haproxy policycoreutils-python-utils bind-utils" || \
    err "Failed to install haproxy and bind-utils"

echo "====> Copying haproxy.cfg to Loadbalancer VM: "
scp -i sshkey haproxy.cfg lb.${CLUSTER_NAME}.${BASE_DOM}:/etc/haproxy/haproxy.cfg || \
    err "Failed to copy haproxy.cfg"

echo 
echo "##################"
echo "#### DNS CHECK ###"
echo "##################"
echo 

echo -n "====> Adding test records in /etc/hosts: "
echo "1.2.3.4 xxxtestxxx.${BASE_DOM}" >> /etc/hosts
systemctl restart libvirtd || err "systemctl restart libvirtd"; ok
sleep 5

echo -n "====> Testing DNS forward record from LB: "
fwd_dig=$(ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "dig +short 'xxxtestxxx.${BASE_DOM}' 2> /dev/null")
test "$?" -eq "0" -a "$fwd_dig" = "1.2.3.4" || err "Testing DNS forward record failed ($fwd_dig)"; ok

echo -n "====> Testing DNS reverse record from LB: "
rev_dig=$(ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "dig +short -x '1.2.3.4' 2> /dev/null")
test "$?" -eq "0" -a "$rev_dig" = "xxxtestxxx.${BASE_DOM}." || err "Testing DNS reverse record failed ($rev_dig)"; ok

echo -n "====> Adding test SRV record in dnsmasq: "
echo "srv-host=xxxtestxxx.${BASE_DOM},yyyayyy.${BASE_DOM},2380,0,10" > ${DNS_DIR}/xxxtestxxx.conf
systemctl $DNS_CMD $DNS_SVC || err "systemctl $DNS_CMD $DNS_SVC failed"; ok

echo -n "====> Testing SRV record from LB: "
srv_dig=$(ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "dig srv +short 'xxxtestxxx.${BASE_DOM}' 2> /dev/null" | grep -q -s "yyyayyy.${BASE_DOM}") || \
    err "ERROR: Testing SRV record failed"; ok

echo -n "====> Cleaning up: "
sed -i "/1.2.3.4 xxxtestxxx.${BASE_DOM}/d" /etc/hosts || err "sed failed"
rm -f ${DNS_DIR}/xxxtestxxx.conf || err "rm failed"
systemctl $DNS_CMD $DNS_SVC || err "systemctl $DNS_CMD $DNS_SVC failed"; ok


echo 
echo "############################################"
echo "#### CREATE BOOTSTRAPING CoreOS/OKD NODES ###"
echo "############################################"
echo 

echo  -n "====> Create bootstrap ignition ISO files /tmp "
echo
# Bootstrap ignition ISO - Not used anymore
#if [ -f /tmp/bootstrap.iso ]; then
#    rm -f /tmp/bootstrap.iso
#fi
if [ -d /tmp/bootstrap_ign ]; then
    rm -rf /tmp/bootstrap_ign
fi
mkdir /tmp/bootstrap_ign
cp ${SETUP_DIR}/install_dir/bootstrap.ign /tmp/bootstrap_ign/config.ign
#genisoimage -output /tmp/bootstrap.iso -volid config-2 -joliet -rock -input-charset utf-8 /tmp/bootstrap_ign/config.ign
#chmod 644 /tmp/bootstrap.iso

#if [ -f /tmp/master.iso ]; then
#    rm -f /tmp/master.iso
#fi
if [ -d /tmp/master_ign ]; then
    rm -rf /tmp/master_ign
fi
mkdir /tmp/master_ign
cp ${SETUP_DIR}/install_dir/master.ign /tmp/master_ign/config.ign
#genisoimage -output /tmp/master.iso -volid config-2 -joliet -rock -input-charset utf-8 /tmp/master_ign/config.ign
#chmod 644 /tmp/master.iso

#if [ -f /tmp/worker.iso ]; then
#    rm -f /tmp/worker.iso
#fi
if [ -d /tmp/worker_ign ]; then
    rm -rf /tmp/worker_ign
fi
mkdir /tmp/worker_ign
cp ${SETUP_DIR}/install_dir/worker.ign /tmp/worker_ign/config.ign
#genisoimage -output /tmp/worker.iso -volid config-2 -joliet -rock -input-charset utf-8 /tmp/worker_ign/config.ign
#chmod 644 /tmp/worker.iso
echo
chmod -R 777 /tmp/*_ign/config.ign
#echo
#ls -la /tmp/*.iso
echo
ls -la /tmp/*_ign/*
echo

# Set BASE_IMAGE variable is mandatory with new CoreOS find function
BASE_IMAGE="${IMAGE%.*}"

echo -n "====> Creating Bootstrap VM: "
cp "${CACHE_DIR}/${BASE_IMAGE}" "${VM_DIR}/${CLUSTER_NAME}-bootstrap.qcow2"
qemu-img resize -f qcow2 "${VM_DIR}/${CLUSTER_NAME}-bootstrap.qcow2" "${DISK_SIZE}G"

virt-install --name ${CLUSTER_NAME}-bootstrap \
  --ram ${BTS_MEM} --cpu host --vcpus ${BTS_CPU} \
  --os-variant fedora-coreos-stable \
  --disk path="${VM_DIR}/${CLUSTER_NAME}-bootstrap.qcow2",format=qcow2,bus=virtio \
  --network network=${VIR_NET},model=virtio \
  --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/tmp/bootstrap_ign/config.ign" \
  --noreboot --noautoconsole --import \
  > /dev/null || err "Creating bootstrap vm failed"; ok

for i in $(seq 1 ${N_MAST})
do
  echo -n "====> Creating Master-${i} VM: "
  cp "${CACHE_DIR}/${BASE_IMAGE}" "${VM_DIR}/${CLUSTER_NAME}-master-${i}.qcow2"
  qemu-img resize -f qcow2 "${VM_DIR}/${CLUSTER_NAME}-master-${i}.qcow2" "${DISK_SIZE}G"

  virt-install --name ${CLUSTER_NAME}-master-${i} \
    --ram ${MAS_MEM} --cpu host --vcpus ${MAS_CPU} \
    --os-variant fedora-coreos-stable \
    --disk path="${VM_DIR}/${CLUSTER_NAME}-master-${i}.qcow2",format=qcow2,bus=virtio \
    --network network=${VIR_NET},model=virtio \
    --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/tmp/master_ign/config.ign" \
    --noreboot --noautoconsole --import \
    > /dev/null || err "Creating master-${i} vm failed "; ok
done

for i in $(seq 1 ${N_WORK})
do
  echo -n "====> Creating Worker-${i} VM: "
  cp "${CACHE_DIR}/${BASE_IMAGE}" "${VM_DIR}/${CLUSTER_NAME}-worker-${i}.qcow2"
  qemu-img resize -f qcow2 "${VM_DIR}/${CLUSTER_NAME}-worker-${i}.qcow2" "${DISK_SIZE}G"

  virt-install --name ${CLUSTER_NAME}-worker-${i} \
    --ram ${WOR_MEM} --cpu host --vcpus ${WOR_CPU} \
    --os-variant fedora-coreos-stable \
    --disk path="${VM_DIR}/${CLUSTER_NAME}-worker-${i}.qcow2",format=qcow2,bus=virtio \
    --network network=${VIR_NET},model=virtio \
    --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/tmp/worker_ign/config.ign" \
    --noreboot --noautoconsole --import \
    > /dev/null || err "Creating worker-${i} vm failed "; ok
done

echo "====> Waiting for CoreOS Installation to finish: "
while rvms=$(virsh list --name | grep "${CLUSTER_NAME}-master-\|${CLUSTER_NAME}-worker-\|${CLUSTER_NAME}-bootstrap" 2> /dev/null); do
    sleep 15
    echo "  --> VMs with pending installation: $(echo "$rvms" | tr '\n' ' ')"
done

echo -n "====> Marking ${CLUSTER_NAME}.${BASE_DOM} as local domain in dnsmasq: "
echo "local=/${CLUSTER_NAME}.${BASE_DOM}/" > ${DNS_DIR}/${CLUSTER_NAME}.conf || err "failed"; ok

echo -n "====> Starting Bootstrap VM: "
virsh start ${CLUSTER_NAME}-bootstrap > /dev/null || err "virsh start ${CLUSTER_NAME}-bootstrap failed"; ok

for i in $(seq 1 ${N_MAST})
do
    echo -n "====> Starting Master-${i} VM: "
    virsh start ${CLUSTER_NAME}-master-${i} > /dev/null || err "virsh start ${CLUSTER_NAME}-master-${i} failed"; ok
done

for i in $(seq 1 ${N_WORK})
do
    echo -n "====> Starting Worker-${i} VMs: "
    virsh start ${CLUSTER_NAME}-worker-${i} > /dev/null || err "virsh start ${CLUSTER_NAME}-worker-${i} failed"; ok
done

echo -n "====> Waiting for Bootstrap to obtain IP address: "
while true; do
    sleep 5
    BSIP=$(virsh domifaddr "${CLUSTER_NAME}-bootstrap" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
    test "$?" -eq "0" -a -n "$BSIP"  && { echo "$BSIP"; break; }
done
MAC=$(virsh domifaddr "${CLUSTER_NAME}-bootstrap" | grep ipv4 | head -n1 | awk '{print $2}')

echo -n "  ==> Adding DHCP reservation: "
virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$BSIP'/>" --live --config > /dev/null || \
    err "Adding DHCP reservation failed"; ok

echo -n "  ==> Adding /etc/hosts entry: "
echo "$BSIP bootstrap.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts || err "failed"; ok


for i in $(seq 1 ${N_MAST}); do
    echo -n "====> Waiting for Master-$i to obtain IP address: "
        while true
        do
            sleep 5
            IP=$(virsh domifaddr "${CLUSTER_NAME}-master-${i}" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
            test "$?" -eq "0" -a -n "$IP"  && { echo "$IP"; break; }
        done
        MAC=$(virsh domifaddr "${CLUSTER_NAME}-master-${i}" | grep ipv4 | head -n1 | awk '{print $2}')

    echo -n "  ==> Adding DHCP reservation: "
    virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config > /dev/null || \
    err "Adding DHCP reservation failed"; ok

    echo -n "  ==> Adding /etc/hosts entry: "
    echo "$IP master-${i}.${CLUSTER_NAME}.${BASE_DOM}" \
         "etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts || err "failed"; ok

    echo -n "  ==> Adding SRV record in dnsmasq: "
    echo "srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${BASE_DOM},etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM},2380,0,10" >> ${DNS_DIR}/${CLUSTER_NAME}.conf || \
        err "failed"; ok
done

for i in $(seq 1 ${N_WORK}); do
    echo -n "====> Waiting for Worker-$i to obtain IP address: "
    while true
    do
        sleep 5
        IP=$(virsh domifaddr "${CLUSTER_NAME}-worker-${i}" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
        test "$?" -eq "0" -a -n "$IP"  && { echo "$IP"; break; }
    done
    MAC=$(virsh domifaddr "${CLUSTER_NAME}-worker-${i}" | grep ipv4 | head -n1 | awk '{print $2}')

    echo -n "  ==> Adding DHCP reservation: "
    virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config > /dev/null || \
    err "Adding DHCP reservation failed"; ok

    echo -n "  ==> Adding /etc/hosts entry: "
    echo "$IP worker-${i}.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts || err "failed"; ok
done

echo -n '====> Adding wild-card (*.apps) dns record in dnsmasq: '
echo "address=/apps.${CLUSTER_NAME}.${BASE_DOM}/${LBIP}" >> ${DNS_DIR}/${CLUSTER_NAME}.conf || err "failed"; ok

echo -n "====> Resstarting libvirt and dnsmasq: "
systemctl restart libvirtd || err "systemctl restart libvirtd failed"
systemctl $DNS_CMD $DNS_SVC || err "systemctl $DNS_CMD $DNS_SVC"; ok


echo -n "====> Configuring haproxy in LB VM: "
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "semanage port -a -t http_port_t -p tcp 6443" || \
    err "semanage port -a -t http_port_t -p tcp 6443 failed" && echo -n "."
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "semanage port -a -t http_port_t -p tcp 22623" || \
    err "semanage port -a -t http_port_t -p tcp 22623 failed" && echo -n "."
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "systemctl start haproxy" || \
    err "systemctl start haproxy failed" && echo -n "."
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "systemctl -q enable haproxy" || \
    err "systemctl enable haproxy failed" && echo -n "."
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "systemctl -q is-active haproxy" || \
    err "haproxy not working as expected" && echo -n "."
ok


if [ "$AUTOSTART_VMS" == "yes" ]; then
    echo -n "====> Setting VMs to autostart: "
    for vm in $(virsh list --all --name --no-autostart | grep "^${CLUSTER_NAME}-"); do
        virsh autostart "${vm}" &> /dev/null
        echo -n "."
    done
    ok
fi


echo -n "====> Waiting for SSH access on Boostrap VM: "
ssh-keygen -R bootstrap.${CLUSTER_NAME}.${BASE_DOM} &> /dev/null || true
ssh-keygen -R $BSIP  &> /dev/null || true
while true; do
    sleep 1
    ssh -i sshkey -o StrictHostKeyChecking=no core@bootstrap.${CLUSTER_NAME}.${BASE_DOM} true &> /dev/null || continue
    break
done
ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" true || err "SSH to lb.${CLUSTER_NAME}.${BASE_DOM} failed"; ok



echo 
echo "###############################"
echo "#### OKD BOOTSTRAPING ###"
echo "###############################"
echo 

cp install_dir/auth/kubeconfig install_dir/auth/kubeconfig.orig
export KUBECONFIG="install_dir/auth/kubeconfig"


echo "====> Waiting for Boostraping to finish: "
echo "(Monitoring activity on bootstrap.${CLUSTER_NAME}.${BASE_DOM})"
a_dones=()
a_conts=()
a_images=()
a_nodes=()
s_api="Down"
btk_started=0
no_output_counter=0
while true; do
    output_flag=0
    if [ "${s_api}" == "Down" ]; then
        ./oc get --raw / &> /dev/null && \
            { echo "  ==> Kubernetes API is Up"; s_api="Up"; output_flag=1; } || true
    else
        nodes=($(./oc get nodes 2> /dev/null | grep -v "^NAME" | awk '{print $1 "_" $2}' )) || true
        for n in ${nodes[@]}; do
            if [[ ! " ${a_nodes[@]} " =~ " ${n} " ]]; then
                echo "  --> Node $(echo $n | tr '_' ' ')"
                output_flag=1
                a_nodes+=( "${n}" )
            fi
        done
    fi
    images=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo podman images 2> /dev/null | grep -v '^REPOSITORY' | awk '{print \$1 \"-\" \$3}'" )) || true
    for i in ${images[@]}; do
        if [[ ! " ${a_images[@]} " =~ " ${i} " ]]; then
            echo "  --> Image Downloaded: ${i}"
            output_flag=1
            a_images+=( "${i}" )
        fi
    done
    dones=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "ls /opt/openshift/*.done 2> /dev/null" )) || true
    for d in ${dones[@]}; do
        if [[ ! " ${a_dones[@]} " =~ " ${d} " ]]; then
            echo "  --> Phase Completed: $(echo $d | sed 's/.*\/\(.*\)\.done/\1/')"
            output_flag=1
            a_dones+=( "${d}" )
        fi
    done
    conts=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo crictl ps -a 2> /dev/null | grep -v '^CONTAINER' | rev | awk '{print \$4 \"_\" \$2 \"_\" \$3}' | rev" )) || true
    for c in ${conts[@]}; do
        if [[ ! " ${a_conts[@]} " =~ " ${c} " ]]; then
            echo "  --> Container: $(echo $c | tr '_' ' ')"
            output_flag=1
            a_conts+=( "${c}" )
        fi
    done

    btk_stat=$(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo systemctl is-active bootkube.service 2> /dev/null" ) || true
    test "$btk_stat" = "active" -a "$btk_started" = "0" && btk_started=1 || true

    test "$output_flag" = "0" && no_output_counter=$(( $no_output_counter + 1 )) || no_output_counter=0

    test "$no_output_counter" -gt "8" && \
        { echo "  --> (bootkube.service is ${btk_stat}, Kube API is ${s_api})"; no_output_counter=0; }

    test "$btk_started" = "1" -a "$btk_stat" = "inactive" -a "$s_api" = "Down" && \
        { echo '[Warning] Some thing went wrong. Bootkube service wasnt able to bring up Kube API'; }
        
    test "$btk_stat" = "inactive" -a "$s_api" = "Up" && break

    sleep 15
    
done


./openshift-install --dir=install_dir wait-for bootstrap-complete


echo -n "====> Removing Boostrap VM: "
if [ -z "$KEEP_BS" ]; then
    virsh destroy ${CLUSTER_NAME}-bootstrap > /dev/null || err "virsh destroy ${CLUSTER_NAME}-bootstrap failed"
    virsh undefine ${CLUSTER_NAME}-bootstrap --remove-all-storage > /dev/null || err "virsh undefine ${CLUSTER_NAME}-bootstrap --remove-all-storage"; ok
else
    ok "skipping"
fi

echo -n "====> Removing Bootstrap from haproxy: "
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" \
    "sed -i '/bootstrap\.${CLUSTER_NAME}\.${BASE_DOM}/d' /etc/haproxy/haproxy.cfg" || err "failed"
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "systemctl restart haproxy" || err "failed"; ok


echo 
echo "#################################"
echo "#### OKD CLUSTERVERSION ###"
echo "#################################"
echo 

echo "====> Waiting for clusterversion: "
ingress_patched=0
imgreg_patched=0
output_delay=0
while true
do
    cv_prog_msg=$(./oc get clusterversion -o jsonpath='{.items[*].status.conditions[?(.type=="Progressing")].message}' 2> /dev/null) || continue
    cv_avail=$(./oc get clusterversion -o jsonpath='{.items[*].status.conditions[?(.type=="Available")].status}' 2> /dev/null) || continue

    if [ "$imgreg_patched" == "0" ]; then
        ./oc get configs.imageregistry.operator.openshift.io cluster &> /dev/null && \
       {
            sleep 30
            echo -n '  --> Patching image registry to use EmptyDir: ';
            ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}' 2> /dev/null && \
                imgreg_patched=1 || true
            sleep 30
            test "$imgreg_patched" -eq "1" && ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState": "Managed"}}' &> /dev/null || true
        } || true        
    fi

    if [ "$ingress_patched" == "0" ]; then
        ./oc get -n openshift-ingress-operator ingresscontroller default &> /dev/null && \
        {
            sleep 30
            echo -n '  --> Patching ingress controller to run router pods on master nodes: ';
            ./oc patch ingresscontroller default -n openshift-ingress-operator \
                --type merge \
                --patch '{
                    "spec":{
                        "replicas": '"${N_MAST}"',
                        "nodePlacement":{
                            "nodeSelector":{
                                "matchLabels":{
                                    "node-role.kubernetes.io/master":""
                                }
                            },
                            "tolerations":[{
                                "effect": "NoSchedule",
                                "operator": "Exists"
                            }]
                        }
                    }
                }' 2> /dev/null && ingress_patched=1 || true
        } || true
    fi

    for csr in $(./oc get csr 2> /dev/null | grep -w 'Pending' | awk '{print $1}'); do
        echo -n '  --> Approving CSR: ';
        ./oc adm certificate approve "$csr" 2> /dev/null || true
        output_delay=0
    done

    if [ "$output_delay" -gt 8 ]; then
        echo -n "  --> ${cv_prog_msg:0:70}"; test -n "${cv_prog_msg:71}" && echo " ..." || echo
        output_delay=0
    fi

    test "$cv_avail" = "True" && break
    output_delay=$(( output_delay + 1 ))
    sleep 15
done

END_TS=$(date +%s)
TIME_TAKEN="$(( ($END_TS - $START_TS) / 60 ))"

echo 
echo "######################################################"
echo "#### OKD 4 INSTALLATION FINISHED SUCCESSFULLY###"
echo "######################################################"
echo "          time taken = $TIME_TAKEN minutes"
echo 

./openshift-install --dir=install_dir wait-for install-complete




# Create an env file to record the vars
# Can be used for future operations


cat <<EOF > env
# OKD4 Automated Install using https://github.com/banyartibi/okd4-to-kvm/
# Script location: ${SDIR}
# Script invoked with: ${SINV}
# OKD: ${OKD_VERSION}
# CoreOS version: ${COREOS_VERSION}
#
# Script start time: $(date -d @${START_TS})
# Script end time:   $(date -d @${END_TS})
# Script finished in: ${TIME_TAKEN} minutes
#
# VARS:

export LBIP="$LBIP"
export WS_PORT="$WS_PORT"
export IMAGE="$IMAGE"
export CLUSTER_NAME="$CLUSTER_NAME"
export VIR_NET="$VIR_NET"
export DNS_DIR="$DNS_DIR"
export VM_DIR="$VM_DIR"
export SETUP_DIR="$SETUP_DIR"
export BASE_DOM="$BASE_DOM"
export NETWORK_TYPE="$NETWORK_TYPE"
export DNS_CMD="$DNS_CMD"
export DNS_SVC="$DNS_SVC"

export KUBECONFIG="${SETUP_DIR}/install_dir/auth/kubeconfig"
EOF
cp ${SDIR}/add_node.sh ${SETUP_DIR}/add_node.sh
cp ${SDIR}/expose_cluster.sh ${SETUP_DIR}/expose_cluster.sh
