[[ _TOC_ ]]
### Kind QuickStart
The purpose of this automation is to install BigBang onto a Kind cluster running on your local machine

### Prerequisites
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [sops](https://github.com/mozilla/sops/releases) Use version 3.5
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)


### Getting Started
- Create an env file from the example ```cp example.env .env```
- Set environment variables in the .env file to fetch dependencies for bigbang and the git repo where your git ops configuration will live.
  - Get your username and password from [Registry1](registry1.dso.mil)
  - Get a access [token](https://gitlab.com/-/profile/personal_access_tokens) from your gitlab account with api permissions
- Run ```deploy.sh```
- Set the branch name to a branch you want your cluster to be managed from. This will be a branch on this [repo](https://gitlab.com/cse5/cognition/bb-template.git)
- Kiali will be the last service to come up, visit kiali.bigbang.dev 

### Go into the dev folder and update your bb configuration
```
cd bb-template/dev/
```
#### Modify your configmap to enable a new service
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
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
```