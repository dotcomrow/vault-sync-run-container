// sync.js
// Sync GCP Secret Manager secret to Vault on trigger

const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const fetch = require('node-fetch');

const client = new SecretManagerServiceClient();

async function main() {
  try {
    const rawEvent = process.env.CLOUD_EVENT || await readStdin();
    const event = JSON.parse(rawEvent);

    const secretVersion = event?.protoPayload?.resourceName;
    if (!secretVersion) throw new Error("Missing secret version in event payload");

    console.log("Accessing secret:", secretVersion);
    const [accessResponse] = await client.accessSecretVersion({ name: secretVersion });
    const payload = accessResponse.payload.data.toString();

    const secretName = extractSecretName(secretVersion);
    const vaultPath = `secret/${secretName}`;

    console.log(`Pushing secret to Vault at path: ${vaultPath}`);
    const response = await fetch(`${process.env.VAULT_ADDR}/v1/${vaultPath}`, {
      method: 'POST',
      headers: {
        'X-Vault-Token': await getVaultToken(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ value: payload })
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Failed to write to Vault: ${text}`);
    }

    console.log("Secret successfully written to Vault.");
  } catch (err) {
    console.error("Error in sync:", err);
    process.exit(1);
  }
}

function extractSecretName(versionPath) {
  const parts = versionPath.split("/");
  return parts[parts.indexOf("secrets") + 1];
}

async function getVaultToken() {
  if (process.env.VAULT_TOKEN) return process.env.VAULT_TOKEN;

  // AppRole auth
  const roleId = process.env.VAULT_ROLE_ID;
  const secretId = process.env.VAULT_SECRET_ID;
  const resp = await fetch(`${process.env.VAULT_ADDR}/v1/auth/approle/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ role_id: roleId, secret_id: secretId })
  });

  const json = await resp.json();
  return json?.auth?.client_token;
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => data += chunk);
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

main();
