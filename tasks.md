## Tasks


After referring to the [this quick-start guide](inseriscisetuplink) to deploy a working testing infrastructure as starting point, it's time to implement all the tasks described below.

### HPC-infrastructure assignments

#### 1. Implement Distributed Storage with Ceph
The first task is to set up a **Ceph**-based distributed storage system within Virtual Orfeo, mirroring the approach used in the production environment. The main steps include:

---
1. **VM Planning**
   We have defined an  **odd number** of VMs to ensure high availability in a Ceph cluster (e.g., 3 or 5).
   The odd number is required due to a quorum-based election mechanism.
   Using three or more nodes in a storage infrastructure also provides several compelling advantages. Enhanced high availability or fault tolerance ensures applications continue running even in the event of two nodes going down.

2. **Add Storage**
   Attach additional storage disks to these VMs to serve as **OSD**.

3. **Deploy a Ceph Cluster**
   Install and configure Ceph across the VMs.

4. **Create a Replicated Pool and File System**
   Once the cluster is up, create a replicated pool and then set up a Ceph file system.

5. **Mount the File System**
   Mount the Ceph file system on all nodes (e.g., at `/orfeo/cephfs/scratch`).



All of these tasks have been automated through the **Ansible** playbooks. 
After you have followed the first tutotial (setup-inserisci link), navigate to:

```
cd units-infra-final/01_ceph/playbooks
```

To bring up all the ceph nodes (needed to simulate the storage nodes), run in your terminal the following command:


```
ansible-playbook 00_all.yml
```

With this `.yml`, you'll bring up three ceph nodes (`ceph01`, `ceph02` and `ceph03`). 
After this it is necessary to connect our ceph nodes to the virtual environmente through:

```
ansible-playbook 05_mount.yml
```

This is done to automate all the steps available at this [tutorial](https://github.com/Foundations-of-HPC/HPC-and-DATA-Infrastructure-2024/blob/main/tutorials/ceph/ceph-deploy.md).

After you have runned all of the playbooks, open this address on chromium (the browser previously used during the setup)

https://192.168.132.81:8443/

It should appear a dashboard like this:


![Ceph Dashboard](images/ceph-dashboard.jpg)

On the ceph dashboard, it's possible to inspect all the details implemented through the ansible playbooks. Navigate to pool to check if they have been created.
Same is for OSDs: navigate to Cluster/OSDs through the GUI.
Also, check if the Cluster/Physical disks if everything has worked.


![Ceph overview](images/ceph-overview.jpg)



#### 2. Enhance Slurm Configuration
As the current Slurm configuration on our virtual machine is minimal and simply queues jobs in submission order,
it's necessary to modify this configuration to resemble a production-like environment by introducing **Quality of Service (QOS)** rules. Specifically:

- **Implement a Debug QOS**:
  Create a high-priority QOS (for example, `orfeo_debug`) that allows short, resource-light jobs to run with high priority regardless of submission order.

  For instance, if jobs `job1`, `job2`, `job3` were submitted, followed by a debug job `dbg1` (with `--qos=orfeo_debug`), the debug job should preempt or be scheduled before the other queued jobs, provided it meets the debug QOS criteria (e.g., minimal resources and short runtime).

The first step is to modify the Slurm configuration by:
- Editing files directly in the **`slurmctld`** pod, or
- Updating the **`slurm-conf`** ConfigMap in the Kubernetes cluster.

In order to do so, let's start inspecting the cluster: use **`k9s`** to browse the pods and ConfigMaps.
The first step to perform from the terminal of your main machine, open k9s in this simple way:

```
k9s
```

after that, a GUI will open. This is what you will see


![k9s GUI](images/k9sGUI.jpg)

On the top of the GUI, you can find lots of ways you can interact with k9s.
Through the &uarr; &darr; of your keyboard, it's possible to select the pod you wanna interact with. In our case, at this step, we want to interact with **slurmctld**, 
which is the pod for scheduling the various jobs.


![k9s GUI options](images/GUImenu.jpg)

After selecting the desired pod, for example you can click on <d> on the keyboard and an entire description of the pod features will appear. 
In our specific case, right now, what it's required to do is to open the shell. To do so, click the *s* letter on the keyboard.
At this point, you will be in **root@slurmctld-p-0**. 
Run this command:

```
vi etc/slurm/slurm.conf
```

We need to modify the priorityweightqos as follows:

```
priorityweightqos=10000
```


To implement to QoS, the documentations we took inspiration from are the following:

[Slurm Quality of Service](https://slurm.schedmd.com/qos.html)

[sacctmgr from Slurm](https://slurm.schedmd.com/sacctmgr.html)

[sacctmgr tips JHPCE](https://jhpce.jhu.edu/slurm/tips-sacctmgr/)


To create and modify the QoS, the command sacctmgr is going to become our bestfriend. 





### Data-infrastructure tasks


#### 3. Deploy and Test the OFED Environment

Complete the deployment and testing of the OFED virtual environment, which includes MinIO and Authentik.
The testing process involves verifying that Authentik and MinIO work correctly, with **both*** a **graphical** login and **API-based access**, utilizing credentials managed by Authentik.

#### 4. File Synchronization

Nomad Oasis is a data management platform that allows users to store and share files.
Since It has its own storage system, it is necessary to synchronize MinIO storage with the Nomad Oasis database.

Deploy Nomad Oasis [following the instructions in the repository](https://github.com/FAIRmat-NFDI/nomad-distro-template?tab=readme-ov-file#deploying-the-distribution)

Design a synchronization procedure between files stored in MinIO and Nomad Oasis, leveraging the APIs provided by both services. The goal is to create an automated mechanism for updating and sharing files.

---

### Deliverables

By the end of this assignment, you should have:

1. A **Ceph** cluster deployed within the Virtual Orfeo environment, with a replicated pool and file system mounted on all nodes.
2. An updated **Slurm** configuration that supports a debug QOS, enabling high-priority scheduling of qualifying short jobs.
3. A well-documented file where you show that you were able to login into MinIO through the Authentik service for an user that you have enrolled in FreeIPA. For what regard the API-based method, feel free to attach any script needed to achieve this result.
4. A synchronization procedure (ideally a script) that allows to download a file from MinIO and upload it to Nomad Oasis and vice versa.

### Computational resources
Because the virtual environment requires significant RAM and CPU resources, a dedicated virtual machine will be provided for your assignments. If you have any questions, concerns, or difficulties, please feel free to reach out at any time.
