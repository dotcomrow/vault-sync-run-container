const express = require('express');
const bodyParser = require('body-parser');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');
const fetch = require('node-fetch');

const app = express();
app.use(bodyParser.json());

const client = new SecretManagerServiceClient();

app.post('/sync-all', async (req, res) => {
  try {
    const [secrets] = await client.listSecrets({
      parent: `projects/${process.env.GCP_PROJECT_ID}`,
    });

    for (const secret of secrets) {
      const name = secret.name;
      const latestVersion = `${name}/versions/latest`;

      const [accessResponse] = await client.accessSecretVersion({ name: latestVersion });
      const payload = accessResponse.payload.data.toString();
      const secretName = extractSecretName(latestVersion);
      const vaultPath = `secret/${secretName}`;

      console.log(`Syncing ${vaultPath}`);
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
        throw new Error(`Failed to sync ${vaultPath}: ${text}`);
      }
    }

    console.log("✅ All secrets synced to Vault.");
    res.status(200).send("All secrets synced.");
  } catch (err) {
    console.error("Error in sync-all:", err);
    res.status(500).send(err.message || "Unknown error");
  }
});


app.post('/', async (req, res) => {
  try {
    const event = req.body;

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
    res.status(200).send("OK");
  } catch (err) {
    console.error("Error:", err);
    res.status(500).send(err.message || "Unknown error");
  }
});

function extractSecretName(versionPath) {
  const parts = versionPath.split("/");
  return parts[parts.indexOf("secrets") + 1];
}

async function getVaultToken() {
  if (process.env.VAULT_TOKEN) return process.env.VAULT_TOKEN;

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

// Listen on $PORT (Cloud Run requirement)
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Sync service listening on port ${PORT}`);
});
