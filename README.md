# OKD 4 Automated Cluster Installation (on QEMU/KVM) Script

Original Work: https://github.com/gunjangarge/okd4-setup-kvm based on https://github.com/kxr/ocp4_setup_upi_kvm

I am updated and reworked the script to work with modern versions of OKD and FCOS/SCOS

You can define your OKD and FCOS versions and now also able to define streams for FCOS not only stable but testing and next too.
Implemented OVNKubernetes as default NetworkType but as some versions between 4.12 and 4.14 can work with both OpenshiftSDN or OVNKubernetes so now there is an option to define NetworkType if you want to use older OKD or those what can run both type.

From 4.12 it's possible to run on SCOS (CentOS Stream CoreOS) instead of FCOS. The last one where we can use FCOS is 4.15.0-0.okd-2024-03-10-010116 while the first version with SCOS only is 4.16.0-okd-scos.1. The default variables will deploy OKD 4.15 with latest matching FCOS release.

There is brand new option to use the openshift-install shipped by the OKD version selected to list matching CoreOS image (FCOS or SCOS) instead of declare it as a variable. It's the highly recommended and bulletproof option to use however the default is still "no" at the moment to ensure we are still able to run older versions of OKD too with this script. From version 4.16 please always use the -S, --find-fcos, --find-scos flag to deploy your cluster and do not use --fcos-version.

### Prerequistes:

- Internet connected physical host running a modern linux distribution
- Virtualization enabled and Libvirt/KVM setup
- DNS on the host managed by dnsmasq or NetworkManager/dnsmasq

## Installing OKD 4 Cluster


| Option  |Description   |
| :------------ | :------------ |
| -O, --okd-version VERSION | You can set this to a specific version like 4.15.0-0.okd-2024-03-10-010116 etc. More info on https://github.com/OKD/okd/releases.<br>Default: 4.15.0-0.okd-2024-03-10-010116 |
| -R, --fcos-version VERSION | You can set a specific FCOS version to use. For example "39.20240210.3.0" etc. More info on https://getfedora.org/coreos/download?tab=metal_virtualized&stream=stable.<br>Default: 39.20240210.3.0  |
| -F, --fcos-stream STREAM | Steam of the image version you trying to download (stable/testing/next)<br>Default: stable |
| -S, --find-fcos, --find-scos | Let the installation script find the matching CoreOS image for your OKD version. Recommended to use with OKD 4.16 or higher versions<br>Default: no |
| -p, --pull-secret FILE | Location of the pull secret file<br>Default: /opt/pull-secret |
| -c, --cluster-name NAME | OKD 4 cluster name<br>Default: okd4 |
| -d, --cluster-domain DOMAIN | OKD 4 cluster domain<br>Default: local |
| -t, --network-type TYPE | OpenShift 4 cluster network type<br>Default: OVNKubernetes |
| -m, --masters N | Number of masters to deploy<br>Default: 3 |
| -w, --worker N | Number of workers to deploy<br>Default: 2 |
| --master-cpu N | Number of CPUs for the master VM(s)<br>Default: 8 |
| --master-mem SIZE(MB) | RAM size (MB) of master VM(s)<br>Default: 16384 |
| --worker-cpu N | Number of CPUs for the worker VM(s)<br>Default: 4 |
| --worker-mem SIZE(MB) | RAM size (MB) of worker VM(s)<br>Default: 8192 |
| --bootstrap-cpu N | Number of CPUs for the bootstrap VM<br>Default: 8 |
| --bootstrap-mem SIZE(MB) | RAM size (MB) of bootstrap VM<br>Default: 16384 |
| --lb-cpu N | Number of CPUs for the load balancer VM<br>Default: 2 |
| --lb-mem SIZE(MB) | RAM size (MB) of load balancer VM<br>Default: 3072 |
| --lb-disk-size SIZE(GB) | DISK maximum size (GB) of load balancer VM<br>Default, Minimum: 10 |
| --disk-size SIZE(GB) | DISK maximum size (GB) of boostrap,master,worker VMs<br>Default: 50, Minimum 20 |
| -n, --libvirt-network NETWORK | The libvirt network to use. Select this option if you want to use an existing libvirt network<br>The libvirt network should already exist. If you want the script to create a separate network for this installation see: -N, --libvirt-oct<br>Default: default |
| -N, --libvirt-oct OCTET | You can specify a 192.168.{OCTET}.0 subnet octet and this script will create a new libvirt network for the cluster<br>The network will be named okd-{OCTET}. If the libvirt network okd-{OCTET} already exists, it will be used.<br>Default: [not set] |
| -v, --vm-dir | The location where you want to store the VM Disks<br>Default: /var/lib/libvirt/images |
| -z, --dns-dir DIR | We expect the DNS on the host to be managed by dnsmasq. You can use NetworkMananger's built-in dnsmasq or use a separate dnsmasq running on the host. If you are running a separate dnsmasq on the host, set this to "/etc/dnsmasq.d"<br>Default: /etc/NetworkManager/dnsmasq.d |
| -s, --setup-dir DIR | The location where we the script keeps all the files related to the installation<br>Default: /root/okd4_setup_{CLUSTER_NAME} |
| -x, --cache-dir DIR | To avoid un-necessary downloads we download the OKD/FCOS files to a cache directory and reuse the files if they exist<br>This way you only download a file once and reuse them for future installs<br>You can force the script to download a fresh copy by using -X, --fresh-download<br>Default: /root/okd4_downloads |
| -X, --fresh-download | Set this if you want to force the script to download a fresh copy of the files instead of reusing the existing ones in cache dir<br>Default: [not set] |
| -k, --keep-bootstrap | Set this if you want to keep the bootstrap VM. By default bootstrap VM is removed once the bootstraping is finished<br>Default: [not set] |
| --autostart-vms | Set this if you want to the cluster VMs to be set to auto-start on reboot<br> Default: [not set] |
| -y, --yes | Set this for the script to be non-interactive and continue with out asking for confirmation<br>Default: [not set] |
| --destroy | Set this if you want the script to destroy everything it has created<br>Use this option with the same options you used to install the cluster<br>Be carefull this deletes the VMs, DNS entries and the libvirt network (if created by the script)<br>Default: [not set] |

### FCOS versions can be found here
    https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/builds.json
    https://builds.coreos.fedoraproject.org/prod/streams/testing/builds/builds.json
    https://builds.coreos.fedoraproject.org/prod/streams/next/builds/builds.json

### OKD versions can be found here
    https://github.com/okd-project/okd/tags

### Examples
    # Deploy OKD 4.19.0-okd-scos.6 cluster (-S is highly recommended to find the matching SCOS image for this OKD version)
    ./okd4_setup_kvm.sh --okd-version 4.19.0-okd-scos.6 -S
    ./okd4_setup_kvm.sh -O 4.19.0-okd-scos.6 -S

    # Deploy OKD 4.20.0-okd-scos.ec.5 cluster with FCOS 42.20250609.3.0
    ./okd4_setup_kvm.sh --okd-version 4.20.0-okd-scos.ec.5 --fcos-version 42.20250609.3.0
    ./okd4_setup_kvm.sh -O 4.20.0-okd-scos.ec.5 -R 42.20250609.3.0

    # Deploy 4.15.0-0.okd-2024-03-10-010116 OKD version with pull secret from a custom location
    ./okd4_setup_kvm.sh --pull-secret ~/pull-secret --okd-version latest
    ./okd4_setup_kvm.sh -p ~/pull-secret -O 4.15.0-0.okd-2024-03-10-010116

    # Deploy OKD 4.15.0-0.okd-2024-03-10-010116 with custom cluster name and domain
    ./okd4_setup_kvm.sh --cluster-name okd45 --cluster-domain lab.test.com --okd-version 4.15.0-0.okd-2024-03-10-010116
    ./okd4_setup_kvm.sh -c okd45 -d lab.test.com -O 4.15.0-0.okd-2024-03-10-010116

    # Deploy OKD 4.15.0-0.okd-2024-03-10-010116 on new libvirt network (192.168.155.0/24)
    ./okd4_setup_kvm.sh --okd-version 4.15.0-0.okd-2024-03-10-010116 --libvirt-oct 155
    ./okd4_setup_kvm.sh -O 4.15.0-0.okd-2024-03-10-010116 -N 155

    # Deploy OKD 4.15.0-0.okd-2024-03-10-010116 with OpenShiftSDN network type
    ./okd4_setup_kvm.sh --okd-version 4.15.0-0.okd-2024-03-10-010116 --network-type OpenShiftSDN
    ./okd4_setup_kvm.sh -O 4.15.0-0.okd-2024-03-10-010116 -t OpenShiftSDN

    # Destory the already installed cluster
    ./okd4_setup_kvm.sh --cluster-name okd45 --cluster-domain lab.test.com --destroy
    ./okd4_setup_kvm.sh -c okd45 -d lab.test.com --destroy


## TODOS

### Update expose_cluster.sh
    Expose cluster script contains outdated haproxy configuration. Do not use it!

### add_node.sh
    Finalize with new image based deployment not yet ready