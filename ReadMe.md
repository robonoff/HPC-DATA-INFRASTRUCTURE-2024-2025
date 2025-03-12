# HPC and Data infrastructure

**Everybody has a testing environment. Some people are lucky enough enough to have a totally separate environment to run production in.**

In many environments, having a dedicated testing setup (separate from production) is essential for developing and experimenting with new ideas—without disrupting live systems. To facilitate this, we have created **Virtual Orfeo**, a testing environment designed to closely replicate the core features of our production HPC cluster.

Virtual Orfeo offers:
- The same authentication and identity management via **FreeIPA**, which integrates the login across all nodes and services.
- A **Slurm** controller deployed through **k3s** (a lightweight Kubernetes distribution).
- A login node and compute nodes resembling those in the production environment.

## Overview of Virtual Orfeo

1. **Authentication**
   Virtual Orfeo uses **FreeIPA** to handle user authentication across compute nodes, login node, and Slurm containers. FreeIPA is installed on a dedicated VM (`ipa01`), allowing centralized user and group management through a web UI. When a new user is added, changes are propagated automatically to all components.

2. **Container-Orchestrated Slurm**
   The **k3s** Kubernetes distribution runs on a dedicated virtual machine (`kube01`), hosting the key Slurm components:

   - **slurmdbd** for accounting
   - **slurmctld** for scheduling the several jobs

   For more information on Slurm components, see:
   [here](https://github.com/Foundations-of-HPC/HPC-and-DATA-Infrastructure-2024/blob/main/tutorials/slurm/slurm.md) and follow the official [documentations](https://slurm.schedmd.com/documentation.html).

3. **Compute Nodes**
   Virtual Orfeo includes one login node (`login01`) and two compute nodes (`node01` and `node02`), organized into three partitions where you can sbatch your jobs:
   - **debug**
   - **p1**
   - **p2**

   While these partitions are not intended for heavy computations, they allow for testing and experimentation with job scheduling and HPC configuration.

## Virtual Machines
   After deploying Virtual Orfeo (by following the provided README), you will have a set of VMs with these IP addresses:

   - `kube01` at `192.168.132.10`
   - `login01` at `192.168.132.50`
   - `node0[1,2]` at `192.168.132.[51,52]`
   - `ipa01` at `192.168.132.70` (hosts FreeIPA; web GUI at [freeipa](https://ipa01.virtualorfeo.test/ipa/ui/)).
     - If the GUI is not reachable, add `192.168.132.70 ipa01.virtualorfeo.test` to `/etc/hosts`.

All of these VMs are defined within the **vagrantfiles** folder.


## Overview of OrfeoKubOverlay

Alongside the `virtualorfeo` repository our testing infrastructure includes also the following one:

[here](https://gitlab.com/area7/datacenter/codes/orfeokuboverlay)

In OrfeoKubOverlay repository are stored all the manifests, values file and charts used to properly configure the `kube01` machine mentioned above.

In particular, the following services are hosted in Kubernetes:

 - `cert-managert`: a simple to use tool which manages all the certificates in the Kuberentes cluster, ensuring secure connection between the services.
 - `prometheus & grafana` as monitoring tools to keep track of the cluster status.
 - `MinIO` is an object storage solution compatible with the Amazon S3 API,
 - `authentik` used as a centralized user management and an API for single sign-on (SSO).

In principle Authentik software has the capability to manage users and groups by itself however, since the FreeIPA is already in place, we will use the FreeIPA as the main source of truth for the users and groups, letting Authentik to authenticate the users against the FreeIPA.
This is done through LDAP queries.

The monitoring aspect is out of the scope of this exam, while all the other services is going to be needed.

After this brief overview, we are glad to conduct you through the entire tutorial. It's divided into two distinguished sections, for the sake of *human* mental health. 

The tutorial to start from is the [setup](https://github.com/robonoff/HPC-DATA-INFRASTRUCTURE-2024-2025/blob/editing-rob/setup.md). After deployed the entire infrastructure, please, follow the [tasks tutorial](https://github.com/robonoff/HPC-DATA-INFRASTRUCTURE-2024-2025/blob/editing-rob/tasks.md).