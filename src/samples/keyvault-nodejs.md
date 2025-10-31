# Azure Key Vault Integration with Node.js

This document provides examples of integrating Azure Key Vault with Node.js applications using Azure Managed Identity.

## Prerequisites

1. Azure Key Vault created and configured
2. App Service with System-Assigned Managed Identity enabled
3. Key Vault access policy granting the managed identity permissions

## Installation

Install required Azure SDK packages:

```bash
npm install @azure/identity @azure/keyvault-secrets
```

## Example 1: Basic Key Vault Access with Managed Identity

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

async function getSecret(secretName) {
  try {
    // DefaultAzureCredential automatically uses managed identity in Azure
    const credential = new DefaultAzureCredential();
    
    // Key Vault URL from environment variable
    const keyVaultName = process.env.KEY_VAULT_NAME;
    const vaultUrl = `https://${keyVaultName}.vault.azure.net`;
    
    // Create secret client
    const client = new SecretClient(vaultUrl, credential);
    
    // Retrieve secret
    const secret = await client.getSecret(secretName);
    
    return secret.value;
  } catch (error) {
    console.error('Error accessing Key Vault:', error.message);
    throw error;
  }
}

// Usage
async function main() {
  const apiKey = await getSecret("my-api-key");
  console.log("Secret retrieved successfully");
  // Use apiKey in your application
}

main().catch(console.error);
```

## Example 2: Key Vault Configuration Provider

Create a reusable Key Vault configuration provider:

```javascript
// config/keyvault.js
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

class KeyVaultConfig {
  constructor() {
    this.credential = new DefaultAzureCredential();
    this.keyVaultName = process.env.KEY_VAULT_NAME;
    
    if (!this.keyVaultName) {
      throw new Error("KEY_VAULT_NAME environment variable is not set");
    }
    
    const vaultUrl = `https://${this.keyVaultName}.vault.azure.net`;
    this.client = new SecretClient(vaultUrl, this.credential);
    this.cache = new Map();
  }

  async getSecret(secretName, useCache = true) {
    try {
      // Check cache first
      if (useCache && this.cache.has(secretName)) {
        return this.cache.get(secretName);
      }

      // Retrieve from Key Vault
      const secret = await this.client.getSecret(secretName);
      
      // Cache the value
      if (useCache) {
        this.cache.set(secretName, secret.value);
      }
      
      return secret.value;
    } catch (error) {
      console.error(`Error retrieving secret '${secretName}':`, error.message);
      throw error;
    }
  }

  async listSecrets() {
    try {
      const secrets = [];
      for await (const secretProperties of this.client.listPropertiesOfSecrets()) {
        secrets.push({
          name: secretProperties.name,
          enabled: secretProperties.enabled,
          createdOn: secretProperties.createdOn,
          updatedOn: secretProperties.updatedOn
        });
      }
      return secrets;
    } catch (error) {
      console.error('Error listing secrets:', error.message);
      throw error;
    }
  }

  clearCache() {
    this.cache.clear();
  }
}

module.exports = new KeyVaultConfig();
```

**Usage:**

```javascript
const keyVaultConfig = require('./config/keyvault');

async function init() {
  // Get database connection string
  const dbConnectionString = await keyVaultConfig.getSecret('db-connection-string');
  
  // Get API keys
  const openaiApiKey = await keyVaultConfig.getSecret('openai-api-key');
  const geminiApiKey = await keyVaultConfig.getSecret('gemini-api-key');
  
  // Use the secrets in your application
  console.log('Configuration loaded from Key Vault');
}

init().catch(console.error);
```

## Example 3: Express.js Middleware

Integrate Key Vault with Express.js:

```javascript
const express = require('express');
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

const app = express();

// Initialize Key Vault client
const credential = new DefaultAzureCredential();
const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
const secretClient = new SecretClient(vaultUrl, credential);

// Middleware to load secrets
async function loadSecrets(req, res, next) {
  try {
    // Load secrets needed for the request
    req.secrets = {
      apiKey: await secretClient.getSecret('api-key').then(s => s.value),
      dbPassword: await secretClient.getSecret('db-password').then(s => s.value)
    };
    next();
  } catch (error) {
    console.error('Failed to load secrets:', error);
    res.status(500).send('Configuration error');
  }
}

// Apply middleware to specific routes
app.get('/api/data', loadSecrets, async (req, res) => {
  // Use secrets from req.secrets
  const apiKey = req.secrets.apiKey;
  // Make API call with the key
  res.json({ message: 'Data retrieved successfully' });
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

## Example 4: Database Connection with Key Vault

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");
const sql = require('mssql');

async function getDatabaseConnection() {
  try {
    // Get Key Vault client
    const credential = new DefaultAzureCredential();
    const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
    const client = new SecretClient(vaultUrl, credential);
    
    // Retrieve database credentials
    const sqlServer = await client.getSecret('sql-server');
    const sqlDatabase = await client.getSecret('sql-database');
    const sqlUser = await client.getSecret('sql-user');
    const sqlPassword = await client.getSecret('sql-password');
    
    // Configure connection
    const config = {
      server: sqlServer.value,
      database: sqlDatabase.value,
      user: sqlUser.value,
      password: sqlPassword.value,
      options: {
        encrypt: true,
        trustServerCertificate: false
      }
    };
    
    // Connect to database
    const pool = await sql.connect(config);
    console.log('Connected to database');
    
    return pool;
  } catch (error) {
    console.error('Database connection failed:', error);
    throw error;
  }
}

// Usage
async function queryDatabase() {
  const pool = await getDatabaseConnection();
  const result = await pool.request().query('SELECT * FROM Users');
  console.log(result.recordset);
  await pool.close();
}

queryDatabase().catch(console.error);
```

## Example 5: Fallback to Environment Variables (Development)

For local development, fall back to environment variables:

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

class ConfigProvider {
  constructor() {
    this.isProduction = process.env.NODE_ENV === 'production';
    
    if (this.isProduction && process.env.KEY_VAULT_NAME) {
      const credential = new DefaultAzureCredential();
      const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
      this.secretClient = new SecretClient(vaultUrl, credential);
    }
  }

  async getConfig(key) {
    try {
      // In production, use Key Vault
      if (this.isProduction && this.secretClient) {
        const secret = await this.secretClient.getSecret(key);
        return secret.value;
      }
      
      // In development, use environment variables
      const envValue = process.env[key.toUpperCase().replace(/-/g, '_')];
      
      if (!envValue) {
        throw new Error(`Configuration key '${key}' not found`);
      }
      
      return envValue;
    } catch (error) {
      console.error(`Error getting config '${key}':`, error.message);
      throw error;
    }
  }
}

// Usage
const config = new ConfigProvider();

async function init() {
  const dbPassword = await config.getConfig('db-password');
  const apiKey = await config.getConfig('api-key');
  
  console.log('Configuration loaded');
}

init().catch(console.error);
```

## Example 6: Updating Secrets (Admin Operations)

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

async function updateSecret(secretName, secretValue) {
  try {
    const credential = new DefaultAzureCredential();
    const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
    const client = new SecretClient(vaultUrl, credential);
    
    // Set or update secret
    await client.setSecret(secretName, secretValue);
    
    console.log(`Secret '${secretName}' updated successfully`);
  } catch (error) {
    console.error('Error updating secret:', error.message);
    throw error;
  }
}

async function deleteSecret(secretName) {
  try {
    const credential = new DefaultAzureCredential();
    const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
    const client = new SecretClient(vaultUrl, credential);
    
    // Delete secret
    const deletePoller = await client.beginDeleteSecret(secretName);
    await deletePoller.pollUntilDone();
    
    console.log(`Secret '${secretName}' deleted successfully`);
  } catch (error) {
    console.error('Error deleting secret:', error.message);
    throw error;
  }
}

// Note: These operations require Set and Delete permissions in Key Vault access policy
```

## Best Practices

### 1. Use DefaultAzureCredential
```javascript
const credential = new DefaultAzureCredential();
```
This automatically handles:
- Managed Identity in Azure
- Azure CLI credentials for local development
- Environment variables
- Visual Studio credentials

### 2. Cache Secrets
Cache secrets in memory to reduce Key Vault calls:
```javascript
const cache = new Map();

async function getCachedSecret(secretName) {
  if (!cache.has(secretName)) {
    const secret = await client.getSecret(secretName);
    cache.set(secretName, secret.value);
  }
  return cache.get(secretName);
}
```

### 3. Handle Errors Gracefully
```javascript
try {
  const secret = await getSecret('my-secret');
} catch (error) {
  if (error.statusCode === 404) {
    console.error('Secret not found');
  } else if (error.statusCode === 403) {
    console.error('Access denied');
  } else {
    console.error('Unknown error:', error);
  }
}
```

### 4. Use Environment Variables for Key Vault Name
Never hardcode the Key Vault name:
```javascript
const keyVaultName = process.env.KEY_VAULT_NAME;
const vaultUrl = `https://${keyVaultName}.vault.azure.net`;
```

### 5. Implement Retry Logic
```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

async function getSecretWithRetry(secretName, maxRetries = 3) {
  const credential = new DefaultAzureCredential();
  const vaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;
  const client = new SecretClient(vaultUrl, credential);

  for (let i = 0; i < maxRetries; i++) {
    try {
      const secret = await client.getSecret(secretName);
      return secret.value;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}
```

## Local Development

For local development without Azure:

1. **Use Azure CLI authentication:**
   ```bash
   az login
   ```

2. **Or set environment variables:**
   ```bash
   export KEY_VAULT_NAME="your-keyvault-name"
   ```

3. **Or use a `.env` file with fallback:**
   ```javascript
   require('dotenv').config();
   
   const secretValue = process.env.MY_SECRET || await getKeyVaultSecret('my-secret');
   ```

## Security Considerations

1. **Never log secret values**
2. **Use managed identity in production** (no credentials needed)
3. **Implement proper access policies** (principle of least privilege)
4. **Rotate secrets regularly**
5. **Enable Key Vault logging and monitoring**
6. **Use soft delete and purge protection** for Key Vault

## Troubleshooting

### Error: "Secret not found"
- Verify the secret exists in Key Vault
- Check the secret name spelling

### Error: "Access denied"
- Verify managed identity is enabled on App Service
- Check Key Vault access policy grants Get/List permissions
- Ensure correct Key Vault URL

### Error: "DefaultAzureCredential failed to retrieve token"
- In Azure: Verify managed identity is enabled
- Locally: Run `az login` or set credentials

## References

- [Azure Identity SDK](https://docs.microsoft.com/javascript/api/@azure/identity)
- [Azure Key Vault Secrets SDK](https://docs.microsoft.com/javascript/api/@azure/keyvault-secrets)
- [Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)
