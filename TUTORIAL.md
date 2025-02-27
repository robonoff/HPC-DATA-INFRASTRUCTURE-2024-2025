# Virtual ORFEO with OFED and Ceph

> *Everybody has a testing environment. Some people are lucky enough enough to have a totally separate environment to run production in.*

## STEP 0: Initial requirements

Use a **Fedora 40** system, as later versoions require additional steps and different distros require different package names and/or additional steps. You can try and adapt the steps to other systems, but it will require some extra work.    

Experimentally, we have determined that the minimum hardware required to follow this tutorial are:

* At least **4 physical cores** (we tried running on a 2 core hyperthreaded system and it didn't work)
* At least **32 GB of RAM** (we tried on a system with 24 GB, it could run everything but *NOMAD Oasis*)
* While not strictly required, an **SSD** is ***VERY*** recommended.

This tutorial is an updated and integrated version of [Isac Pasianotto's tutorial](https://gitlab.com/IsacPasianotto/testing-env-doc).

## CLONE THE REQUIRED REPOS

For this to work, we will need the repos for [Virtual ORFEO](https://gitlab.com/area7/datacenter/codes/virtualorfeo), [the one specific for the kubernetes overlay](https://gitlab.com/area7/datacenter/codes/orfeokuboverlay) and [the one we made for Ceph](https://gitlab.com/dododevs/units-infra-final).  

Download them using `SSH`:  
```
git clone git@gitlab.com:area7/datacenter/codes/virtualorfeo.git
```

```
git clone git@gitlab.com:area7/datacenter/codes/orfeokuboverlay.git
```

```
git clone git@gitlab.com:dododevs/units-infra-final.git
```  

we will need a specific branch for `orfeokuboverlay`, so run:  

 ```
 cd orfeokuboverlay/
 git checkout hotfixes/authentik
 ```

## INTIAL SETUP

### Install the Requirements

Move into `virtualorfeo` and run:
```
git submodule init && git submodule update --remote
sudo dnf install -y $(sed -r '/^#/d' requirements.txt)
```

Then install other packages that will be required but might not have already been installed:  

* the Python version of *Kubernetes*, the *jq* package:

```
sudo dnf -y install jq python3-kubernetes
```

* You should already have `kubectl` installed, but let's also install the `kustomize` command independently (required by one of the *playbooks* for *MinIO*)

```
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo mv kustomize /usr/local/bin/
```

* Install *Jetstack* (required by a *kuboverlay* *playbook*):

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### Install the Required Plugins

The tested provider for *vagrant* is *libvirt*, hence install the *vagrant* plugin for it, enable the services and add your user to the *libvirt* group.

```
vagrant plugin install vagrant-libvirt
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $(whoami)
```

Now, to apply the command *usermod* you need to log out and back in again. If you're running locally, you can reboot the system to make sure; otherwise, you can just use `su - $(whoami)` to login again in the current *bash*.  

To check if the settings applied correctly, run `groups`. If you see *libvirt* listed, you're good to go.

### Export Global Variables

We will need some variables to be defined globally.  

First of all, we need to indicate where to find the configuration file for kubernetes.  

If you don't have any more clusters, you can edit the *.bashrc* to include these, otherwise you probably already know how to operate:

```
export KUBECONFIG=<path-to-your-project-folder>/virtualorfeo/playbooks/kube_config
```

Then we add a variable to find the *orfeokuboverlay* directory:

```
export ROOTPROJECTDIR=<path-to-your-project-folder>/orfeokuboverlay
```

Add both (or just the second) to the *.bashrc*.

## BRING UP THE FIRST COMPONENTS

We will now run a limited version of the infrastracture to perform the setup for *OFED*.  

### Run the First Playbook

Move into the right directory:

```
cd <path-to-your-project-folder>/virtualorfeo/playbooks
```

and apply/install the required *ansible* settings:

```
ansible-galaxy install --role-file roles/requirements.yml --force
```

After that is done, run the first *playbook* in a limited capacity by selecting only the commands tagged with _kub_:

```
ansible-playbook 00_main.yml --tags kub
```

This is to ensure only the strictlynecessary commands are run, so that we can first enlarge the VM where *kubernetes* is running to fit everything.  

### SIMPLE PROXY (optional)

Placeholder for the *simple proxy* part. Required if running remotely via `SSH`.

### Enlarge the VM's Storage

Now, to make all the required pods and services fit in the `Kubernetes` VM, we need to enlarge it.  

First of all, let's get the ID of the *kube01*  VM:

```
vagrant global-status
```

stop it

```
vagrant halt <kube01-id>
```

then modify the image by adding 5 GB

```
sudo qemu-img resize /var/lib/libvirt/images/k3s_nodes_kube01.img +5G
```

Now let's turn the machine back up again:

```
vagrant up <kube01-id>
```

then log into it as `root`:

```
ssh root@192.168.132.10
```

and run the following command:

```
cfdisk /dev/vda
```

use the &uarr; &darr; pf your keyboard to navigate to `/dev/vda4`, then use the &larr; &rarr; to select `Resize`, press `Enter` to confirm the new fisk size; then selectr `Write`, confirm writing `yes` and `Enter`, then `Enter` again to `Quit`.  

Now expand the `root` partition by running

```
sudo btrfs filesystem resize max /
```

and then

```
df -h
```

to check if the edit took.

### Add the Hostnames for some of the VMs

> **NOTE** : check later if other addresses need to be addressed

Edit the *hosts* file to add hostnames:

```
echo "192.168.132.70 ipa01.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.100 auth.k3s.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.100 minio.k3s.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
```

### Export the Certificates from IPA

Moreover, even if is not strictly necessary, to avoid the browser warning due to the `unknown CA`, it is recommended to add the *ipa CA* to the `system trusted CA`.  

Export the certificates from the *ipa* VM:

```
scp root@ipa01.virtualorfeo.it:/etc/ipa/ca.crt /tmp/freeipa-virtorfeo.crt
```

then move it to the list of `ca-trusted` sources:

```
sudo mv /tmp/freeipa-virtorfeo.crt /etc/pki/ca-trust/source/anchors/freeipa-virtorfeo.crt
```

Then update the list:

```
sudo update-ca-trust
```

### Deploy the Cert-Mamanger

Enter into the *playbook* directory:

```
cd $ROOTPROJECTDIR/playbooks
```

then let's run the first two *playbooks*.  
The first one enables the *ACME* challenge

```
ansible-playbook 01_ipa_acme_enable.yml
```

then the second one handles the certifications through `kubernetes` and the `ipa` server.  

In order to work, `cert-manager` requires a valid issuer. Since all the setup is a testing environment, with a private DNS and CA (IPA), The ipa node is used as `ClusterIssuer`:

```
kubectl apply -f $ROOTPROJECTDIR/00-cert-manager/environment/dev/clusterIssuer/k3s.virtualorfeo.it.yaml
```

### Install Authentik


