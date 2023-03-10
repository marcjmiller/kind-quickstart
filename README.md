[[_TOC_]]
### Kind QuickStart
The purpose of this automation is to install BigBang onto a Kind cluster running on your local machine

### Prerequisites
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [sops version 3.5.0](https://github.com/mozilla/sops/releases/tag/v3.5.0)
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [docker](https://docs.docker.com/engine/install/ubuntu/)

### Getting Started
- Create an env file from the example ```cp example.env .env```
- Set environment variables in the .env file to fetch dependencies for bigbang and the git repo where your git ops configuration will live.
  - Get your username and CLI Secret from [Registry1](https://registry1.dso.mil) for REGISTRY1_USERNAME and REGISTRY1_PASSWORD
![Registry1Image](img/image2.png)
![Registry1Image](img/image1.png)
  - Create an [access token](https://gitlab.com/-/profile/personal_access_tokens) from your gitlab account with api permissions and set your GIT_ACCESS_TOKEN to that.
- Set the GIT_BRANCH_NAME to a *new* branch you want your cluster to be managed from. This will be a branch on this [repo](https://code.il2.dso.mil/trash-pandas/bb-template)
- Run ```deploy.sh```, grab some coffee, it'll take around 10-15 minutes to complete
- Kiali will be the last service to come up, visit http://kiali.bigbang.dev

### Go into the dev folder and update your bb configuration
```
cd bb-template/dev/
```
#### Modify the `configmap.yaml` to enable a new service
```yaml
...
twistlock:
  enabled: false # Set to true
  values:
    console:
      persistence:
        size: 5Gi
...
```
Push the new configuration and watch your cluster update all GitOps like
```bash
git commit -am "enable twistlock"
git push
watch kubectl hr,po -A
```

### Cleanup
- To teardown run ```teardown.sh```

### Troubleshooting
If elasticsearch doesn't come up please do the following to give the image the minimum space it needs
```bash
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

Similarly, fluentbit may enter crashLoopBackoff for an error `[TIMESTAMP] [error] [plugins/in_tail/tail_fs_inotify.c:305 errno=24] Too many open files`, the below are possible fixes for that
```bash
sysctl -w fs.inotify.max_user_instances=1500
echo "fs.inotify.max_user_instances=1500" | sudo tee -a /etc/sysctl.conf
```
Also check for a low value set, and change as below
```bash
cat /proc/sys/fs/inotify/max_user_watches

# If the value of the cmd above is low, then adjust like this
sysctl -w fs.inotify.max_user_watches=525000
echo "fs.inotify.max_user_watches=525000" | sudo tee -a /etc/sysctl.conf
```
