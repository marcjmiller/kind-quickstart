### Kind QuickStart
The purpose of this automation is to install BigBang onto a Kind cluster running on your local machine

### Prerequisites
- Kind
- kubectl
- sops
- git


### Getting Started
- Create an env file from the example ```cp example.env .env```
- Set environment variables in the .env file to fetch dependencies for bigbang and the git repo where your git ops configuration will live.
  - Get your username and password from [Registry1](registry1.dso.mil)
  - Get a access [token](https://gitlab.com/-/profile/personal_access_tokens) from your gitlab account with api permissions
- Run ```deploy.sh```
- Set the branch name to a branch you want your cluster to be managed from. This will be a branch on this [repo](https://gitlab.com/cse5/cognition/bb-template.git)