cat <<TMPL
%%bash

cat <<SCRIPT > /content/datalab/.config/startup.sh
apt-get -o APT::Sandbox::User=root update 

# Upgrade git
if ! (git --version | greq -q 2.14.2); then
  pushd .
  apt-get -o APT::Sandbox::User=root install -y build-essential libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext gzip
  cd /usr/local/src
  curl -sSLO https://github.com/git/git/archive/v2.14.2.tar.gz
  tar zxf v2.14.2.tar.gz
  rm -f v2.14.2.tar.gz
  cd git-2.14.2
  make prefix=/usr/local all
  make prefix=/usr/local install
  popd
  rm -rf /usr/local/src/git-2.14.2
fi

apt-get -o APT::Sandbox::User=root remove -y git
hash -r

# Create .ssh directory
if ! [[ -d /content/datalab/.config/.ssh ]]; then
  mkdir /content/datalab/.config/.ssh
  chmod 700 /content/datalab/.config/.ssh
fi

# Create Deploy Key file
apt-get -o APT::Sandbox::User=root install -y jq

cat <<EOF > /content/datalab/.config/.ssh/id_rsa.encrypted
$(cat id_rsa.encrypted)
EOF

curl -s -X POST "https://cloudkms.googleapis.com/v1/projects/$(gcloud config get-value project)/locations/global/keyRings/${KEYRING}/cryptoKeys/${KEYNAME}:decrypt" \\\\
  -d "{\\"ciphertext\\":\\"\\\$(cat /content/datalab/.config/.ssh/id_rsa.encrypted)\\"}" \\\\
  -H "Authorization: Bearer \\\$(gcloud auth application-default print-access-token)" \\\\
  -H "Content-Type: application/json" \\\\
  | jq ".plaintext" \\\\
  | tr -d '"' \\\\
  | base64 -d \\\\
  > /content/datalab/.config/.ssh/id_rsa
  
chmod 600 /content/datalab/.config/.ssh/id_rsa

# Clone git repository
git config --global core.sshCommand "ssh -i /content/datalab/.config/.ssh/id_rsa -oStrictHostKeyChecking=no"
pushd .
cd /content/datalab/notebooks
if ! (git remote -v | grep "${REPOSITORY}"); then
  popd
  rm -rf /content/datalab/notebooks
  git clone git@github.com:${REPOSITORY}.git /content/datalab/notebooks
fi

# Clean up
rm -f /content/datalab/.config/startup.sh

SCRIPT
TMPL
