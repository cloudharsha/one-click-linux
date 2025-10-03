# one-click-linux
One-Click Setups is a collection of battle-tested, idempotent scripts that install and configure common tools on a fresh machine with a single command.

## One-click installs (Ubuntu)

You can run any script directly without cloning the repo.

### Install
```bash
### Install Docker + Compose v2
curl -fsSL https://raw.githubusercontent.com/cloudharsha/one-click-linux/main/docker-install.sh | bash

### Install kubectl 
curl -fsSL https://raw.githubusercontent.com/cloudharsha/one-click-linux/main/kubectl-install.sh | bash

### Install kind 
curl -fsSL https://raw.githubusercontent.com/cloudharsha/one-click-linux/main/kind-install.sh | bash