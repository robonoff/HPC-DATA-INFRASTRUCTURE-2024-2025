# Virtual ORFEO with OFED and Ceph
> *Everybody has a testing environment. Some people are lucky enough to have a totally separate environment to run production in.*

## STEP 0: Initial requirements

Use a **Fedora 40** system, as later versions require additional steps and different distros require different package names and/or additional steps. You can try and adapt the steps to other systems, but it will require some extra work.    

Experimentally, we have determined that the minimum hardware required to follow this tutorial are:

* At least **4 physical cores** (we tried running on a 2 core hyperthreaded system and it didn't work)
* At least **32 GB of RAM** (we tried on a system with 24 GB, it could run everything but *NOMAD Oasis*)
* While not strictly required, an **SSD** (any kind: SATA, PCIe Gen 2, 3, 4, whatever) is ***VERY*** recommended.

This tutorial is an expanded version of [Isac Pasianotto's tutorial](https://gitlab.com/IsacPasianotto/testing-env-doc).

## CLONE THE REQUIRED REPOS

For this to work, we will need the repos for [Virtual ORFEO](https://gitlab.com/area7/datacenter/codes/virtualorfeo), [the one specific for the kubernetes overlay](https://gitlab.com/area7/datacenter/codes/orfeokuboverlay) and [the one we made for Ceph](https://gitlab.com/dododevs/units-infra-final).  

Download them using `SSH`:  

```bash
git clone git@gitlab.com:area7/datacenter/codes/virtualorfeo.git
```

```bash
git clone git@gitlab.com:area7/datacenter/codes/orfeokuboverlay.git
```

```bash
git clone git@gitlab.com:dododevs/units-infra-final.git
```  

we will need a specific branch for `orfeokuboverlay`, so run:  

 ```bash
 cd orfeokuboverlay/
 git checkout hotfixes/authentik
 ```

## INTIAL SETUP

### Install the Requirements

Move into `virtualorfeo` and run:

```bash
git submodule init && git submodule update --remote
sudo dnf install -y $(sed -r '/^#/d' requirements.txt)
```

Then install other packages that will be required but might not have already been installed:  

* the Python version of *Kubernetes*, the *jq* package:

```bash
sudo dnf -y install jq python3-kubernetes
```

* You should already have `kubectl` installed, but let's also install the `kustomize` command independently (required by one of the *playbooks* for *MinIO*)

```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo mv kustomize /usr/local/bin/
```

* Install *Jetstack* (required by a *kuboverlay* *playbook*):

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

* *(OPTIONAL)* Install *Chromium*, which works better for certificates and proxies:

```bash
sudo dnf install chromium
```

### Install the Required Plugins

The tested provider for *vagrant* is *libvirt*, hence install the *vagrant* plugin for it, enable the services and add your user to the *libvirt* group.

```bash
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

```bash
export KUBECONFIG=<path-to-your-project-folder>/virtualorfeo/playbooks/kube_config
```

Then we add a variable to find the *orfeokuboverlay* directory:

```bash
export ROOTPROJECTDIR=<path-to-your-project-folder>/orfeokuboverlay
```

Add both (or just the second) to the *.bashrc*.

## BRING UP THE FIRST COMPONENTS

We will now run a limited version of the infrastructure to perform the setup for *OFED*.  

### Run the First Playbook

Move into the right directory:

```bash
cd <path-to-your-project-folder>/virtualorfeo/playbooks
```

and apply/install the required *ansible* settings:

```bash
ansible-galaxy install --role-file roles/requirements.yml --force
```

After that is done, run the first *playbook* in a limited capacity by selecting only the commands tagged with _kub_:

```bash
ansible-playbook 00_main.yml --tags kub
```

This is to ensure only the strictly necessary commands are run, so that we can first enlarge the VM where *kubernetes* is running to fit everything.  

### SIMPLE PROXY (optional)

Placeholder for the *simple proxy* part. Required if running remotely via `SSH`.

### Enlarge the VM's Storage

Now, to make all the required pods and services fit in the `Kubernetes` VM, we need to enlarge it.  

First of all, let's get the ID of the *kube01*  VM:

```bash
vagrant global-status
```

stop it

```bash
vagrant halt <kube01-id>
```

then modify the image by adding 5 GB

```bash
sudo qemu-img resize /var/lib/libvirt/images/k3s_nodes_kube01.img +5G
```

Now let's turn the machine back up again:

```bash
vagrant up <kube01-id>
```

then log into it as `root` in kube01:

```bash
ssh root@192.168.132.10
```

and run the following command:

```bash
cfdisk /dev/vda
```

use the &uarr; &darr; of your keyboard to navigate to `/dev/vda4`, then use the &larr; &rarr; to select `Resize`, press `Enter` to confirm the new fisk size; then select `Write`, confirm writing `yes` and `Enter`, then `Enter` again to `Quit`.  

Now expand the `root` partition by running

```bash
sudo btrfs filesystem resize max /
```

and then

```bash
df -h
```

to check if the edit took place.  

Now exit the VM by either pressing `Ctrl`+`d` or by writing `exit`.

### Add the Host Names for Some of the VMs

> **NOTE** : check later if other addresses need to be addressed

Edit the *hosts* file to add host names:

```bash
echo "192.168.132.70 ipa01.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.100 auth.k3s.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.100 minio.k3s.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.100 s3.k3s.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.50 login01 login01.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.51 node01 node01.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.52 node02 node02.virtualorfeo.it" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.81 ceph01" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.82 ceph02" | sudo tee -a /etc/hosts > /dev/null
echo "192.168.132.83 ceph03" | sudo tee -a /etc/hosts > /dev/null
```

### Export the Certificates from IPA

Moreover, even if is not strictly necessary, to avoid the browser warning due to the `unknown CA`, it is recommended to add the *IPA CA* to the `system trusted CA`.  

Export the certificates from the *IPA* VM:

```bash
scp root@ipa01.virtualorfeo.it:/etc/ipa/ca.crt /tmp/freeipa-virtorfeo.crt
```

then move it to the list of `ca-trusted` sources:

```bash
sudo mv /tmp/freeipa-virtorfeo.crt /etc/pki/ca-trust/source/anchors/freeipa-virtorfeo.crt
```

Then update the list:

```bash
sudo update-ca-trust
```

### **[OPTIONAL]** Install k9s

`k9s` is a very useful GUI interface to monitor and manage the pods running in *kubernetes*. 

Add the required repo and install it like so:

```bash
sudo dnf -y copr enable luminoso/k9s
sudo dnf -y install k9s
```

then run it in a separate terminal by running the command `k9s`; press `Enter` to connect, then press `0` on the keyboard to show all of the *namespaces*. 

### Deploy the Cert-Manager

Enter into the *playbook* directory:

```bash
cd $ROOTPROJECTDIR/playbooks
```

then let's run the first two *playbooks*.  
The first one enables the *ACME* challenge

```bash
ansible-playbook 01_ipa_acme_enable.yml
```

then

```bash
ansible-playbook 02_kube_acme_enable.yml
```

then the second one handles the certifications through `kubernetes` and the `IPA` server.  

In order to work, `cert-manager` requires a valid issuer. Since all the setup is a testing environment, with a private DNS and CA (IPA), The IPA node is used as `ClusterIssuer`:

```bash
kubectl apply -f $ROOTPROJECTDIR/00-cert-manager/environment/dev/clusterIssuer/k3s.virtualorfeo.it.yaml
```

### Install Authentik

The installation of *authentik* is done using *helm*:

```bash
cd $ROOTPROJECTDIR/20-authentik
```

then add the repo

```bash
helm repo add authentik https://charts.goauthentik.io
helm repo update
```

and finally install it with the appropriate settings:

```bash
helm install auth authentik/authentik \
  --version 2024.4.2 \
  --namespace authentik \
  --create-namespace \
  -f values.yaml \
  -f environments/dev/values.yaml
```

## SET UP *IPA* AS USER-SOURCE FOR *Authentik*

Technically, *authentik* is able to define users and group directly in its database, but in this way those users will exists only in the *authentik* database. To avoid this, it is possible to use an external user-source, in this case, the *IPA* server relying of *LDAP*.

### Create Bind Account

> **NOTE**: add instructions on how to open Chromium using the proxy when accessing the machine remotely. 

Start *Chromium* (or whatever browser you want) and navigate to `ipa01.virtualorfeo.it`. Login with the admin credentials:

* username: `admin`
* password: `12345678`

Click on `Identity` &rarr; `Users` &rarr; `+Add`and register an `svc_authentik` user which will be used by *authentik* to bind to the *LDAP* server.

![svc user add](images/svc_user-add.png)

 > <span style="color:red;"> !!! WARNING !!! </span> during the user creation, `freeIPA` does not require to set a password, however *authentik* will need it to bind to the *LDAP* server. Remember to set a password (in a test environment like this also a simple one as `12345678` is fine). Remember to fill it out even for future users.
 
 > <span style="color:red">  !!! WARNING !!! </span> now it's unimportant, but you can set the `$HOME` and `shell` of the user from here.

 Once you filled the form up, click on `Add and Edit` button.  
At this point, a new dashboard will show (in case it doesn't, click on the svc_authentick just created). Click on the `Roles` settings tab and assign to the user the `User Administrators` roles clicking on the `Add` button:

![Add administrator role to svc user](images/svc_user-edit.png)

### Authentik First Setup

Before configuring the *LDAP* source in *authentik*, it is needed perform the fist access and create an admin user. To do that open a web browser and go to `auth.k3s.virtualorfeo.it/if/flow/initial-setup/` (be mindful, the final `/` is vital. It could be automatically removed by your browser; in that case, you will land on the wrong page. Just add it back and you should be good to go).  

Then enter an email (e.g. `admin@virtualorfeo.it`) and a password (eg `12345678`) and click on the `Create` button.  
 
This will setup the credentials for the *Authentik*’s default administrator `akadmin`.

### Configure an *LDAP* source in *authentik*

* Click on `Admin interface` &rarr; `Directory` &rarr; `Federation and Social Login` &rarr; `Create`.  
* Select *LDAP* source and click on `Next`.
* Set up with the following  values:  
    1. On the *main* section:

        * **Name**: `freeipa`
        * **Slug**: `freeipa`
        * Leave **enabled** the `Enabled`, `Sync Users`, `Sync Groups` and `Use Password writeback` options

    ![First page of the LDAP setup](images/authentik-ldap-first-tab.png)

    2. In the *Connection Settings* section:

        * **Server URI**: `ldaps://ipa01.virtualorfeo.it`
        * **Disable** the toggle for `Enable StartTLS`
        * **Bind CN**:` uid=svc_authentik,cn=users,cn=accounts,dc=virtualorfeo,dc=it`
        * **Bind Password**: `12345678` (or the password you set to the svc_authentik user in the previous step)
        * **Base DN**: `dc=virtualorfeo,dc=it`
    
    ![Second page of the LDAP setup](images/authentik-ldap-second-tab.png)

    3. In *LDAP Attribute Mapping* section:

        * In **User Property Mappings** Select (multiple selection using `ctlr`):

            * Authentik default LDAP Mapping: DN to User Path
            *Authentik default LDAP Mapping: mail
            * Authentik default LDAP Mapping: Name
            * authentik default OpenLDAP Mapping: cn
            * authentik default OpenLDAP Mapping: uid
        
        * In the **Group Property Mappings** Select: `authentik default OpenLDAP Mapping: cn`

    ![Third page of the LDAP setup](images/authentik-ldap-third-tab.png)

    4. In the `Additional Setting`:

        * **Addition User DN**: `cn=users,cn=accounts`
        * **Addition Group DN**: `cn=users,cn=accounts`
        * **User Object Filter**: `(objectClass=person)`
        * **Group Object Filter**: `(objectClass=groupofnames)`
        * **Group membership field**: `member`
        * **Object uniqueness field**: `ipaUniqueID`

    ![Last page of the LDAP setup](images/authentik-ldap-last-tab.png)

    5. Click on the `Finish` button, then click on the `freeipa` name, then on the `Run sync` button. It won't automatically update, so you have to either refresh the page or navigate in and out of the page to see if it updated. It will display errors, do not worry.

    ![Sync page](images/authentik-sync.png)

    6. Test the configuration by going to *ipa* and create a test user with whatever name you like (e.g. `user00` or `test_user`) - without forgetting to set a password! - and then use the `Run sync again` button. If you open the hamburger menu, then `Directory` &rarr; `Users` and see it listed, your setup is working.

### Register the *MinIO* App in *Authentik*

Once *Authentik* is proper configure to retrieve users from the *ipa* server, the next step is to configure *authentik* to act as a unique place to login for several services.
In our example we are going to use *MinIO* as an example, but the same procedure can be repeated with other applications.

#### Define a scope mapping

The primary way to manage accesses in *MinIO* is via policies, We need to configure *authentik* to return a list of which *MinIO* policies should be applied to a user.  
For this reason the first step is to set it up. Access with a web browser to `auth.k3s.virtualorfeo.it`, go to the `Admin interface` and click on:  

`Customization` &rarr; `Property Mappings` &rarr; `Create` and select:

* `LDAP Property Mapping` &rarr; Next
* **Name**: *Provider for minio*
+ **Object Field**: `minio`
* **Expression**:
```
return {
  "policy": "readwrite",
}
```

#### Create an Application and a Provider in *authentik*

Since release `2024.2` *Authentik* provider a wizard which allows to define in a single shot both an `Application` and a `Provider` instances automatically configured to be used together.  
To use that go to the `Admin interface` and then:

`Applications` &rarr; `Applications` &rarr; `Create with Wizard`, and select:

* In the **Application Details** tab:
    
      
    + **name**: `minio`  
    * **slug**: `minio`
    * **Policy engine mode**: `any`
    * **UI.settings** &rarr; **Launch URL** : `https://minio.k3s.virtualorfeo.it`

![MinIO provider first tab](images/authentik-minio-first-tab.png)

* In **Provider Type** tab select `OAuth2/OIDC (Open Authorization/OpenID Connect)` (you will have to scroll up to find it) and click `Next`.
* In the **Configure OAuth2/OpenId Provider** tab select:

    * **Name**:`Provider for MinIO`
    * **Authentication flow**: `default-authentication-flow (Welcome to Authentik)` (it's drop down menu, the first option)
    * **Authorization flow**: `default-provider-authorization-explicit-consent (Authorize Application)` (it's drop down menu, again the first option)

![MinIO provider](images/authentik-minio-second-tab.png)

> !!! WARNING !!! Ensure to save in a safe place the `Client ID` and most importantly the `Client Secret` values, as you will need it immediately after this step and finding them again is a bit of a pain.

* Scroll down and in the **Protocol Settings** section:

    * **Client type** : `confidential`
    * **Redirect URIs/Origins (RegEx)**: `https://minio.k3s.virtualorfeo.it/oauth_callback`

![MinIO secrets](images/authentik-minio-third-tab.png)

### Deploy *MinIO*

The installation of *minio* is done using `kustomize`. First of all go in the *minio* folder and create a `minio-dev` namespace:  

```
cd $ROOTPROJECTDIR/minio
kubectl create namespace minio-dev
```

#### Retrieve the CA certificate and trust it

*Minio* by default will not trust any third-party CA, so it is needed to provide the CA certificate to trust it.  
This will be passed as a secret to the *minio* pod:

```
kubectl get secrets --namespace authentik authentik-tls -o yaml | awk '/tls\.crt/{print $2}' | base64 --decode > /tmp/chain.pem
TRUSTED_CA_CRT=$(sed -n '/-----BEGIN CERTIFICATE-----/{:a;p;n;/-----END CERTIFICATE-----/!ba;p;q}' /tmp/chain.pem)
export TRUSTED_CA_CRT_ENCODED=$(echo -n "$TRUSTED_CA_CRT" | base64 | sed 's/^/    /')
envsubst < ca-secret.yaml | kubectl apply -f -
```

#### Edit the customization file for kustomize

Edit the file `./dev/kustomization.yaml` (which is located inside the `minio` folder we switched into) by using the text editor you like best:

```
nano ./dev/kustomization.yaml
```

and in `"MINIO_IDENTITY_OPENID_CLIENT_ID`" and `"MINIO_IDENTITY_OPENID_CLIENT_SECRET`", replace the `REDACTED` entries with the *app ID* and the *secret* we saved in the previous step.  

After that, in the `"MINIO_IDENTITY_OPENID_ROLE_POLICY"`, replace `"readwrite"` entry with `consoleAdmin`. This ensures that for later steps we have the right permissions.  

![kustomize](images/kustomization.png)

Now create the manifest to apply and apply it:

```
kustomize build dev > dev/manifest.yaml
kubectl apply -f dev/manifest.yaml
```

Finally, to test that everything is working, open a web browser and go to `https://minio.k3s.virtualorfeo.it` and try to login with the user `user00` and the password you set in the *ipa* server. If everything works, you should see something like this

![minio login](images/minio_sso.png)

which will redirect you to the *authentik* login page. It should also ask for confirmation.  

if that works, you're done with the initial setup.

## DEPLOY THE REST OF THE VIRTUAL ORFEO INFRASTRUCTURE

Now run the rest of the playbooks found in `virtualorfeo/playbooks`. So, move into that directory. You can either re-run the playbook 00 without tags like so

```bash
ansible-playbook 00_main.yml
```

alternatively - and probably better - run them one by one (except the ones that start with a 9, which are there to handle the destruction, pausing and restarting the cluster).  

> !!! IMPORTANT !!! you need to run this command to prevent the `kube01` *cronjobs* from completely filling up your pod space:

```bash
kubectl delete cronjob slurm-cronjob -n slurm
```

## DEPLOY CEPH

Now everything is in order to deploy the *ceph* cluster. We will use Andrea Esposito's playbook.  

Move into the right directory:

```bash
cd <path-to-your-project-directory>/units-infra-final/01_ceph/playbooks
```

> NOTE: it's important not to run the playbooks from just any directory because some configuration files need you to be in the same directory as the playbook to work  

This will take a while, so it will probably fail due to time limits being exceeded. If that's the case, just run the mount playbook alone:

```bash
ansible-playbook 05_mount.yml
```

If everything work, you're done! Let's check it on the login node. Run:

```bash
ssh root@login01
```

then

```bash
cd /mnt/testfs/
touch test_file
```

if this works, it's a good indicator we are good to go. To really make sure, let's log in into one of the compute nodes. Log out of `login01` and then:

```bash
ssh root@node01
```

then

```bash
cd /mnt/testfs/
ls -l
```

if you see the same `test_file` we made while in the `login01` node, we actually are on the distributed filesystem.

## [OPTIONAL - POORLY TESTED] Automatically create a home directry on the Ceph cluster for each user and use it as such

This part is entirely optional and it has not really been tested much. In the previous step, we used the `root` user for a reason: actually the directory we were using is owned by `root`, so other users do not have *write* permissions, so we would not have been able to create the `test_file`.  

This is already a problem, but the main issue is that the current home directory is not shared so this could lead to issues when running anything on the nodes, since they can't access the same files as the login node can.  

We can solve both of these problems at once by editing some configuration files to automatically create a directory named as the user on the *ceph* cluster, and automatically set it as the *home*.  


### Authenticate and change default home settings

First of all, let's authenticate in *FreeIPA*:

```bash
kinit admin
```

it will require the password for *FreeIPA* which is, if you didn't change it, `12345678`.  

Now let's update the default new *home* directory:

```bash
ipa config-mod --homedirectory=/mnt/testfs/home
```

let's check whether it worked:

```bash
ipa config-show | grep 'Home directory base'
```

if all looks good, let's proceed.

### Enforce the changes

Now we need to edit some configuration files to enforce the changes.  

Edit the *sssd.conf* file by adding an override command to the `[domain/default]` section:

```bash
override_homedir = /mnt/testfs/home/%u
```

then save and restart the *SSSD*:

```bash
sudo systemctl restart sssd
```

Now, we need to edit two more files. The first one is the *pam* *sshd*, found at

```bash
sudo nano /etc/pam.d/sshd
```

where you need to add BEFORE `session include password-auth` this line:

```bash
session required pam_mkhomedir.so skel=/etc/skel umask=0077
```

save and exit.  

Insert the same line in `/etc/pam.d/system-auth`:

```bash
sudo nano /etc/pam.d/system-auth
```

Now restart the *SSH* service:

```
sudo systemctl restart sshd
```

### Test the change

Log in with a user you have never logged in with before, for example:

```bash
ssh user01@login01
```

then check the path of the home. If all is right, you should see

```bash
pwd
```

```bash
/mnt/testfs/user01
```

## Configure *SLURM* Users

We will now configure the *slurm* users and partitions to work properly and then set the *QoS* to differentiate use cases.  

### Gather Info

Now, your *slurm* install should not yet have any of the *FreeIPA* accounts added to any of the partitions.  

Login in `root` in the `login01` node:

```bash
ssh root@login01
```

Let's first of all list the users currently added to *slurm*:

```bash
sacctmgr show users
```

you should get this output:

```bash
      User   Def Acct     Admin 
---------- ---------- --------- 
      root       root Administ+ 

```

Login into *kerberos* to access *FreeIPA* from CLI (again, use the password `12345678` when requested):

```bash
kinit admin
```

You should now be able to successfully run this command

```bash
ipa user-find --all | awk '/User login/ {user=$3} /UID:/ {print user, $2}'
```

and get something like this output

```bash
admin 584000000
svc_authentik 584000003
user00 584000004
user01 584000005
user02 584000006
user03 584000007
```

### *QoS* Management

Now let's check out the *QoS* and [optionally] modufy it:

```bash
sacctmgr show qos
```

this should show just the `default` one, with `Priority 0` and little else. To update it, for example to add a time limit for jobs, you can run something like:

```bash
sacctmgr modify qos normal set MaxWall=01:00:00
```

Let's create a new `debug` *QoS*, with limited resources (shorter max wall time) but higher priority:

```bash
acctmgr add qos debug set MaxWall=00:01:00 Priority=10000
```

write `y` to confirm.  

Now, all of this will be completely useless if we don't edit the configuration file to take into account the priority values set by the *QoS*. Let's do that by editing a configuration file found in the *slurm* controller. This is not persistent between destructions of the *kubernetes* VM, for that yoy would need to edit the configuration files used by the playbooks.  

**SEE ROBERTA'S PART**

### Create an Account, Add the Users, Associate the QoS

Now let's create an `account` to associate with the future users:

```bash
sacctmgr add account <account-name> cluster=orfeo Priority=0
```

confirm by pressing `y`. Add users 

```bash
sacctmgr add user <user-name> cluster=orfeo Partition=p1,p2,debug Account=<account-name>
```

agin press `y` to confirm, then let's finally add the *QoS* and set the *Default QoS*:

```bash
sacctmgr modify user <user-name> set qos+=normal,debug
```

press `y` to confirm, then run the two commands for all of the users.  Now add the default *QoS*:

```bash
sacctmgr modify account <account-name> set DefaultQOS=normal
```

and press `y` to confirm. You can check whether it worked or not by running

```bash
sacctmgr show association
```

Now apply the changes with

```bash
scontrol reconfigure
```

It should now work. You can logout from `root` and login using any of the users you added and trying something like

```bash
srun -p p1 --pty bash
```

### Modify the Configuration File to Make it Work

Now, since the partition configuration take precedence on the account and user configurations, we need to edit a configuration file to make the *priority* take effect.  

Open `k9s`, use &uarr; and &darr; to navigate to the pod called `slurmctld-p-0` and press `s`. Now run

```bash
vi /etc/slurm/slurm.conf
```

and find the line `priorityweightqos=0`. Press `i` to enter *insertion* mode, replace the `0` with a `10000`, then press `Esc`, write `:wq` to write the file to save it and then quit the editor and then `Enter`.  

Log out, now login as `root` in `login01`

```bash
ssh root@login01
```

and again run this command to apply the change

```bash
scontrol reconfigure
```

**images in Roberta's part**

Now to test whether it worked or not, we need to run 3 jobs using any of the configured normal users. To do so, we need a `job` file to `sbatch` with different options in such a way to create a queue, and check whether the job with the higher priority gets started before the one with the lower priority.  

Here's the most basic file to do so, a `job` that just waits for 60 seconds.

```bash
nano test.sh
```

```bash
#!/bin/bash

#SBATCH --account=default
#SBATCH --error=error_%j.log

sleep 60

```

```bash
chmod +x test.sh
```

now let's sbatch it twice specifying the normal *QoS*:

```bash
sbatch -p p1 --qos=normal --job_name=normal_0 test.sh
```

```bash
sbatch -p p1 --qos=normal --job_name=normal_1 test.sh
```

and then sbatch it with the higher priority *QoS*

```bash
sbatch -p p1 --qos=debug --job_name=debug test.sh
```

now run `squeue` to see the queue, what's in it and what's being run. Either you can cancel the running job with`scancel <job-id>`, then run `squeue` again and check if the `debug` job is being run ahead of `normal_1`, or you can just wait and run `watch squeue` and see what happens.  

## Running *MinIO* with the *API* client `mc`

It is possible to run *MinIO* from command line or using a script, for example a *Python* one, using the appropriate *API*. To do so, one needs to install the proper packages, libraries and follow the right set up steps.  

### Get the secret key

First of all, let's generate the `access key`. To do so, navigate to [https://minio.k3s.virtualorfeo.it/](https://minio.k3s.virtualorfeo.it/), login using the admin credentials for *Authentik* and go to the `Access Keys` section.

![Homepage of the MinIO web interface](images/minio_home.png)

Then click on `Create access key` button

![Inteface for the access key management](images/minio_acces_key_button.png)

click on the `Create` button

![Access key reation interface](images/minio_access_key_create_button.png)

which will open an interface with the key and a button to download the *json* containing the keys. Do so, as this will be the last time they will be shown and using the file is more useful than having them written somewhere.  

![Accesss key json format download button](images/minio_access_key_json_download.png)

Now if you are using a remote machine/VM via proxy, you should note that the file should have been saved on your local machine. Upload the file using `scp` to the remote machine (assuming you downloaded in `Downloads/`)

```bash
scp $HOME/Download/credentials.json <shortcut-to-your-remote>:<path-to-your-project-directory>
```

### Install the `mc` client

Now, we need to install the packages required to run the *API* calls for *MinIO* from the CLI. You can find the complete documentation [here](https://min.io/docs/minio/linux/reference/minio-mc.html).  

Install it by downloading the binaries then moving them to the appropriate location:

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc \
cd $HOME/minio-binaries \
chmod +x mc
```

```bash
sudo cp mc /usr/bin
```

Test it by running

```bash
mc --version
```

If everything is fine, proceed.

> NOTE: the system might offer to install the package for you. DO NOT ACCEPT. That is a different command also called `mc` which has nothing to do with this.

### Create the *alias*

Get the access and secret keys from the `credentials.json` and paste them in a `.env` file like so:

```bash
nano .env
```

```bash
MINIO_ACCESS_KEY=fhcMdSrkR1OVWbP8MzaL
MINIO_SECRET_KEY=7xEhk6FZBAcYbUmw30w2v2OU9eZ6D36rekzerX99
```

then add this line to to the `.bashrc` export them as variables in every new shell

```bash
export $(cat /path/to/your/.env | xargs)
```

then either log out and back in, close the terminal and open a new one or run `source .bashrc`.  

Now you can actually create the alias to use for the *API* calls by running:

```bash
mc alias set <alias> https://s3.k3s.virtualorfeo.it $MINIO_ACCESS_KEY  $MINIO_SECRET_KEY
```

if you see an output like

```bash
Added `minio` successfully.
```

you are done. 

### Using the *API* to make calls

The documentation provided explains from this point onwards how to make calls to create buckets (basically the equivalent of directories), upload, edit, list or download files, etc.  

For testing purposes, you can also use them via a *Python* script - one example is provided in the [*scripts*](scripts/) directory of this repo.

## *NOMAD* *Oasis*

### Uninstall *podman*

First of all we need to uninstall *podman*, which is used within some of the VMs and was thus installed via the requirements, but we don't actually need it on the host machine. So:

```bash
sudo dnf remove -y podman
```

### Install *Docker*

Install *Docker*:

```bash
 sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
```

```bash
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Enable it:

```bash
sudo systemctl enable --now docker
```

Optionally, you could run the `hello-world` container to test it:

```bash
sudo docker run hello-world
```

### Install *NOMAD*

Clone the repo:

```bash
git clone https://github.com/FAIRmat-NFDI/nomad-distro-template.git
```

move into the directory

```bash
cd nomad-distro-template
```

and just run the `compose up`command:

```bash
sudo docker compose up -d
```

It will take a while the first time.

### Operate *NOMAD*

Open the [web interface](http://localhost/nomad-oasis/) you can find at [`http://localhost/nomad-oasis/`](http://localhost/nomad-oasis/).  

Now you need to create an account with `nomad-lab` by following the button present at the top right of the page. Note that this is an ACTUAL account, so you need to pick an actually secure password for it.  

![NOMAD interface](images/nomad_interface.png)

![NOMAD registration](images/nomad_register.png)

From here, using the 

Once you logged in, you can navigate using the `ANALYZE` &rarr; `APIs` to get to this page

![NOMAD APIs page, get the token from the clipboard button](images/nomad_apis.png)

and use the date menu to set the expiration date of the token; besides that, there's a *clipboard* button. When you click on it, the access token will be added to you clipboard. Now you can paste it wherever you want. Save it somewhere.  

Now we will create a `.env` file in a dedicated directory:

```bash
mkdir -p nomad
cd nomad
nano .env
```

the format should be along the lines of this one:

```bash
nomad_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoiZjQ4ODZjN2MtZjNkMC00ZTEyLTk5MjktM2NiY2YwOTE3Mjc0IiwiZXhwIjoxNzQyMzM4ODAwfQ.q9LdxR8vZwSatykIT7QP5jD-XPdYScE76tOKh2xo7hU
minio_url=https://s3.k3s.virtualorfeo.it
minio_access_key=58WnsTvOjRwIuh2Ffxbv
minio_secret_key=CxyBzlIuNgn9jvl2HPXC03a1WzPl939mddrxv0Xd
```

Now, to upload a 
