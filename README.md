Google Cloud Datalab with GitHub
================================

# Steps
## Configure Variables
```bash
export PROJECT=my-project
export KEYRING=testkeyring
export KEYNAME=testkey
export DATALAB_NAME=testlab
export REPOSITORY=nownabe/datalab-test
export SERVICE_ACCOUNT=my-service-account@my-project.iam.gserviceaccount.com
```

## Create Deploy Key
```bash
ssh-keygen -t rsa -b 4096 -N '' -f id_rsa
```

Add `id_rsa.pub` into the repository as a deploy key with write access.

## Encrypt Deploy Key with Cloud KMS

Create KeyRing.

```bash
gcloud kms keyrings create ${KEYRING} --location global
```

Create CryptoKey.

```bash
gcloud kms keys create ${KEYNAME} --location global --keyring ${KEYRING} --purpose encryption
gcloud kms keys remove-rotation-schedule ${KEYNAME} --location global --keyring ${KEYRING}
```

Add Compute Engine default service account as a decrypter.

```bash
gcloud kms keys add-iam-policy-binding ${KEYNAME} \
  --location global \
  --keyring ${KEYRING} \
  --member "serviceAccount:${SERVICE_ACCOUNT}" \
  --role "roles/cloudkms.cryptoKeyDecrypter"
```

Encrypt deploy key.

```bash
plaintext=$(<id_rsa base64)
curl -s -X POST \
  "https://cloudkms.googleapis.com/v1/projects/${PROJECT}/locations/global/keyRings/${KEYRING}/cryptoKeys/${KEYNAME}:encrypt" \
  -d "{\"plaintext\":\"$plaintext\"}" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  | jq ".ciphertext" \
  | tr -d '"' \
  > id_rsa.encrypted
```

## Create Datalab

Create datalab instance with a service account that has access to KMS decryption.

```bash
datalab create ${DATALAB_NAME}
```

## Create startup.sh

See https://cloud.google.com/datalab/docs/how-to/adding-libraries.

Create this notebook.

Execute `bash template.sh` and copy output.
Then paste it to a new notebook and run.

You should push this notebook to Cloud Source Repositories `datalab-notebooks`.

## Restart Datalab Instance
Restart Datalab instance.
Top right icon > About Datalab > Restart Server
