#!/bin/sh
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

datenum=$(expr $(date +%s) + 0)
dirstring="$((datenum % 10000))dir"
retries=5
while true; do
  res=$(mkdir $dirstring 2>&1)
  if echo "$res" | grep -Eq '^.{0}$'; then
    break
  fi
  sleep 5
  datenum=$(expr $(date +%s) + 0)
  dirstring="$((datenum % 10000))dir"
  retries=$((retries - 1))
  if [ $retries -eq 0 ]; then
    echo "Failed to create directory"
    exit 1
  fi
done

curl https://sdk.cloud.google.com > install.sh
bash install.sh --disable-prompts --install-dir=./$dirstring >/dev/null 
PATH=$PATH:./$dirstring/google-cloud-sdk/bin
printf '%s' "$GOOGLE_CREDENTIALS" > key.json
gcloud auth activate-service-account --key-file=key.json

SHA=$(gcloud artifacts docker images list us-docker.pkg.dev/$2/gcr.io/$1 --sort-by="~UPDATE_TIME" --limit=1 --format="value(format('{0}',version))")
# retries=5
# while true; do
#   if echo "$SHA" | grep -Eq '^sha256\:[0-9a-f]{64}$'; then
#     break
#   fi
#   sleep 5
#   SHA=$(gcloud artifacts docker images list us-docker.pkg.dev/$2/gcr.io/$1 --sort-by="~UPDATE_TIME" --limit=1 --format="value(format('{0}',version))")
#   retries=$((retries - 1))
#   if [ $retries -eq 0 ]; then
#     echo "Failed to get SHA for image us-docker.pkg.dev/$2/gcr.io/$1"
#     exit 1
#   fi
# done

cat <<EOF
{
  "sha": "$SHA"
}
EOF