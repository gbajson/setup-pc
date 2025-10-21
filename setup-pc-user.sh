#!/usr/bin/env bash
set -Eeuo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

venv_dir=".venv"
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

VARS=$(python3 - "$@" << EOF
import argparse
import shlex
parser = argparse.ArgumentParser(prog="$0", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

# Add arguments here
parser.add_argument('-v', '--verbose', action='count', default=0)
parser.add_argument('--venv-dir', required=False, default="$venv_dir", help="Virtual environment directory")
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



mkdir -p tmp
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env bash
fi

venv_dir=$(realpath "$venv_dir")

# Setup Python and venv
uv python install 3.13
uv python pin 3.13
uv venv "$venv_dir" --allow-existing
source "$venv_dir/bin/activate"
uv pip install -r <(uv pip compile pyproject.toml)

export PATH="$venv_dir"/bin:$PATH

git config --global user.email "$git_email"
git config --global user.name "$git_name"

# configure lazydocker
install -m 600 -D config-lazydocker.yml  ~/.config/lazydocker/config.yml
