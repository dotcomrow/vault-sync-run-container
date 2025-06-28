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

export NONINTERACTIVE=1

# Make sure DOCKER_VERSION is still set
DOCKER_VERSION=24.0.6

# Download Docker CLI
curl -L https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz | tar xz
export PATH="$PWD/docker:$PATH"

# 🛠️ Install buildx plugin manually
mkdir -p ~/.docker/cli-plugins
curl -SL "https://github.com/docker/buildx/releases/download/v0.14.1/buildx-v0.14.1.linux-amd64" -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx

# Confirm it works
docker buildx version

./google-cloud-sdk/bin/gcloud auth configure-docker

npm run build

docker buildx create --name mybuilder --use
docker buildx build --platform linux/amd64 \
  --tag "$REGION-docker.pkg.dev/$COMMON_PROJECT_ID/$REGISTRY_NAME/$PROJECT_NAME:latest" \
  --push .
