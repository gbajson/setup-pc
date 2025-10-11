#!/usr/bin/env bash
set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

venv_dir=".venv"

trap on_error ERR
on_error() {
  echo
  echo "########################"
  echo "#### SCRIPT FAILED. ####"
  echo "########################"
}

if [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
  echo "Error: This script requires Bash 5.x or higher. You are using Bash $BASH_VERSION."
  exit 1
fi

VARS=$(python3 - "$@" << EOF
import argparse
import shlex
parser = argparse.ArgumentParser(prog="$0", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

# Add arguments here
parser.add_argument('-v', '--verbose', action='count', default=0)
parser.add_argument('--venv-dir', required=False, default="$venv_dir", help="Virtual environment directory")
args = parser.parse_args()
for k, v in vars(args).items():
    print("{}={}".format(k, shlex.quote(str(v))))
EOF
)
if echo "$VARS" | grep -q "^usage:"; then
  echo "$VARS"
  exit 1
fi
eval $VARS
[[ $verbose > 0 ]] && set -x

mkdir -p tmp
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

venv_dir=$(realpath "$venv_dir")

# Setup Python and venv
uv python install python3.12
uv venv "$venv_dir" --allow-existing --python=python3.12
source "$venv_dir/bin/activate"
uv pip install -r <(uv pip compile pyproject.toml)

export PATH="$venv_dir"/bin:$PATH

if ! command -v docker &> /dev/null; then
  if [[ $(lsb_release -i | grep -i "ubuntu") ]]; then
    sudo apt-get update
    ansible-galaxy install geerlingguy.docker
    ansible-playbook "$script_dir"/install-docker.yml
  else
    echo "Please install docker."
    echo "Documentation: https://docs.docker.com/engine/install/"
    exit 1
  fi
fi

# Check if docker is running
docker run -it --rm hello-world

# Check docker compose version
docker version
docker compose version

