curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz

tar -xf google-cloud-cli-linux-x86_64.tar.gz

./google-cloud-sdk/install.sh

printf '%s' "$GOOGLE_CREDENTIALS" > key.json

./google-cloud-sdk/bin/gcloud auth activate-service-account --key-file=key.json

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

nvm install node

npm install

mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C homebrew

eval "$(homebrew/bin/brew shellenv)"
brew update --force --quiet
chmod -R go-w "$(brew --prefix)/share/zsh"

# export NONINTERACTIVE=1

# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install glibc
brew install gcc
# brew install svn
# brew install podman





# apt-get install -y uidmap
# export SKIP_IPTABLES=1
# curl -fsSL https://get.docker.com/rootless | sh

# ./google-cloud-sdk/bin/gcloud auth configure-docker

# npm run build

# docker build . -t $PROJECT_NAME:latest

# docker tag $PROJECT_NAME $REGION-docker.pkg.dev/$COMMON_PROJECT_ID/$REGISTRY_NAME/$PROJECT_NAME:latest

# docker push $REGION-docker.pkg.dev/$COMMON_PROJECT_ID/$REGISTRY_NAME/$PROJECT_NAME:latest


