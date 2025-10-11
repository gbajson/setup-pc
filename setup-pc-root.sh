#!/usr/bin/env bash
set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

venv_dir=".venv"
user="gbajson"
uid="1001"
gid="1001"
git_email="gbajson@protonmail.ch"
git_name="Grzegorz Bajson"



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

if [ "$EUID" -ne 0 ]; then
  echo "Run this script as root."
  exit 1
fi

VARS=$(python3 - "$@" << EOF
import argparse
import shlex
parser = argparse.ArgumentParser(prog="$0", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

# Add arguments here
parser.add_argument('-v', '--verbose', action='count', default=0)
parser.add_argument('--venv-dir', required=False, default="$venv_dir", help="Virtual environment directory")
parser.add_argument('--user', required=False, default="$user", help="Username")
parser.add_argument('--uid', required=False, default="$uid", help="UID")
parser.add_argument('--gid', required=False, default="$gid", help="GID")
parser.add_argument('--git-email', required=False, default="$git_email", help="Git user email")
parser.add_argument('--git-name', required=False, default="$git_name", help="Git user name")
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

if ! command -v uv &> /dev/null; then
    tmpdir=$(mktemp -d)
    (
        cd $tmpdir
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source $HOME/.local/bin/env bash
    )
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
    apt-get update
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

ansible localhost -c local -b -m ansible.builtin.group -a "name=$user gid=$gid state=present"
ansible localhost -c local -b -m ansible.builtin.user -a "name=$user uid=$uid group=$user create_home=yes shell=/bin/bash state=present"

user_home_dir=$(getent passwd gbajson | cut -d: -f6)
install -m 600 -g "$user" -o "$user" -D /root/.ssh/authorized_keys "$user_home_dir"/.ssh/authorized_keys

cd "$user_home_dir"
test -d "$user_home_dir"/setup-pc && rm -fr "$user_home_dir"/setup-pc
sudo -u "$user" git clone https://github.com/gbajson/setup-pc.git

git config --global user.email "$git_email"
git config --global user.name "$git_name"


