# Azure Key Vault Integration for Node.js

This document provides code samples for integrating Azure Key Vault with your Node.js application using the Azure SDK and Managed Identity.

## Prerequisites

Install the required Azure SDK packages:

```bash
npm install @azure/keyvault-secrets @azure/identity
```

## Using DefaultAzureCredential (Recommended)

`DefaultAzureCredential` automatically handles authentication in different environments:
- **In Azure**: Uses Managed Identity (no credentials needed)
- **Locally**: Uses Azure CLI credentials or environment variables

### Basic Example: Reading Secrets

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

// Key Vault name should be set in environment variable
const keyVaultName = process.env.KEY_VAULT_NAME || "your-keyvault-name";
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

// Create credential and client
const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUrl, credential);

async function getSecret(secretName) {
  try {
    const secret = await client.getSecret(secretName);
    console.log(`Secret ${secretName} retrieved successfully`);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    throw error;
  }
}

// Example usage
(async () => {
  try {
    const dbConnectionString = await getSecret("DatabaseConnectionString");
    const apiKey = await getSecret("DeepSeekApiKey");
    
    console.log("Secrets retrieved successfully");
    // Use the secrets in your application
  } catch (error) {
    console.error("Failed to retrieve secrets:", error);
  }
})();
```

## Complete Integration Example

Here's a complete example showing how to integrate Key Vault with your Express.js application:

```javascript
const express = require('express');
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

const app = express();
const PORT = process.env.PORT || 3000;

// Key Vault client setup
let secretClient;
let secrets = {};

async function initializeKeyVault() {
  const keyVaultName = process.env.KEY_VAULT_NAME;
  
  if (!keyVaultName) {
    console.warn("KEY_VAULT_NAME not set, skipping Key Vault initialization");
    return;
  }

  try {
    const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
    const credential = new DefaultAzureCredential();
    secretClient = new SecretClient(keyVaultUrl, credential);
    
    // Pre-load commonly used secrets
    secrets.dbConnectionString = await getSecret("DatabaseConnectionString");
    secrets.deepSeekApiKey = await getSecret("DeepSeekApiKey");
    secrets.geminiApiKey = await getSecret("GeminiApiKey");
    
    console.log("Key Vault initialized successfully");
  } catch (error) {
    console.error("Failed to initialize Key Vault:", error.message);
    // Fallback to environment variables if Key Vault is unavailable
    secrets.dbConnectionString = process.env.DATABASE_CONNECTION_STRING;
    secrets.deepSeekApiKey = process.env.DEEPSEEK_API_KEY;
    secrets.geminiApiKey = process.env.GEMINI_API_KEY;
  }
}

async function getSecret(secretName) {
  try {
    const secret = await secretClient.getSecret(secretName);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    return null;
  }
}

// Initialize Key Vault before starting server
initializeKeyVault().then(() => {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}).catch((error) => {
  console.error("Startup error:", error);
  process.exit(1);
});

// Example route using secrets
app.get('/api/config', (req, res) => {
  res.json({
    hasDbConnection: !!secrets.dbConnectionString,
    hasApiKeys: !!secrets.deepSeekApiKey || !!secrets.geminiApiKey
  });
});
```

## Caching Secrets

For better performance, cache secrets and refresh periodically:

```javascript
class KeyVaultCache {
  constructor(keyVaultUrl) {
    this.credential = new DefaultAzureCredential();
    this.client = new SecretClient(keyVaultUrl, this.credential);
    this.cache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes
  }

  async getSecret(secretName, forceRefresh = false) {
    const now = Date.now();
    const cached = this.cache.get(secretName);

    if (!forceRefresh && cached && (now - cached.timestamp) < this.cacheTTL) {
      return cached.value;
    }

    try {
      const secret = await this.client.getSecret(secretName);
      this.cache.set(secretName, {
        value: secret.value,
        timestamp: now
      });
      return secret.value;
    } catch (error) {
      console.error(`Error retrieving secret ${secretName}:`, error.message);
      // Return cached value if available, even if expired
      return cached ? cached.value : null;
    }
  }

  clearCache() {
    this.cache.clear();
  }
}

// Usage
const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
const kvCache = new KeyVaultCache(keyVaultUrl);

// Get secret (will be cached)
const apiKey = await kvCache.getSecret("DeepSeekApiKey");

// Force refresh
const refreshedApiKey = await kvCache.getSecret("DeepSeekApiKey", true);
```

## Listing All Secrets

```javascript
async function listAllSecrets() {
  const keyVaultName = process.env.KEY_VAULT_NAME;
  const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
  const credential = new DefaultAzureCredential();
  const client = new SecretClient(keyVaultUrl, credential);

  console.log("Secrets in Key Vault:");
  
  for await (const secretProperties of client.listPropertiesOfSecrets()) {
    console.log(`- ${secretProperties.name}`);
  }
}
```

## Error Handling

```javascript
async function getSecretWithRetry(secretName, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const secret = await client.getSecret(secretName);
      return secret.value;
    } catch (error) {
      if (attempt === maxRetries) {
        console.error(`Failed to retrieve secret ${secretName} after ${maxRetries} attempts`);
        throw error;
      }
      
      console.warn(`Attempt ${attempt} failed, retrying...`);
      await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
    }
  }
}
```

## Local Development

For local development, use Azure CLI authentication:

```bash
# Login to Azure CLI
az login

# Set the subscription (if you have multiple)
az account set --subscription <subscription-id>

# Test Key Vault access
az keyvault secret show --vault-name <your-keyvault-name> --name <secret-name>
```

Set environment variables for local development:

```bash
# .env file (for local development only - DO NOT COMMIT)
KEY_VAULT_NAME=your-keyvault-name
# Fallback values
DATABASE_CONNECTION_STRING=your-local-db-connection
DEEPSEEK_API_KEY=your-local-api-key
```

## Managed Identity in Azure

When running in Azure App Service, the Managed Identity is automatically configured:

1. **System-Assigned Identity**: Enabled in Bicep/Terraform templates
2. **Key Vault Access**: Granted via RBAC (Key Vault Secrets User role)
3. **No Credentials Needed**: `DefaultAzureCredential` automatically uses Managed Identity

### Verify Managed Identity

```bash
# Check if identity is enabled
az webapp identity show --name <app-service-name> --resource-group <rg-name>

# Check role assignments
az role assignment list --assignee <principal-id> --scope /subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.KeyVault/vaults/<keyvault-name>
```

## Best Practices

1. **Use Managed Identity**: Avoid storing credentials in code or configuration
2. **Cache Secrets**: Reduce Key Vault API calls by caching with reasonable TTL
3. **Handle Failures Gracefully**: Implement retry logic and fallbacks
4. **Rotate Secrets**: Update secrets in Key Vault without redeploying app
5. **Use Key Vault References**: For App Service, use Key Vault references in app settings
6. **Monitor Access**: Enable Key Vault logging and monitor access patterns
7. **Least Privilege**: Grant only necessary permissions to Managed Identity

## Key Vault References in App Service

Instead of fetching secrets in code, you can reference them directly in App Service app settings:

```bash
az webapp config appsettings set \
  --name <app-service-name> \
  --resource-group <rg-name> \
  --settings \
    "DATABASE_CONNECTION_STRING=@Microsoft.KeyVault(SecretUri=https://<keyvault-name>.vault.azure.net/secrets/DatabaseConnectionString/)"
```

Then access in Node.js as a regular environment variable:

```javascript
const dbConnectionString = process.env.DATABASE_CONNECTION_STRING;
```

This approach is simpler and automatically handles secret rotation.

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure Managed Identity is enabled
   - Verify RBAC role assignment
   - Check that app has restarted after identity creation

2. **Secret Not Found**
   - Verify secret name (case-sensitive)
   - Check Key Vault name is correct
   - Ensure secret exists in Key Vault

3. **Permission Denied**
   - Verify role assignment (Key Vault Secrets User or higher)
   - Check Key Vault is using RBAC authorization model

4. **Network Issues**
   - Ensure app can reach Key Vault endpoint
   - Check firewall rules if Key Vault has network restrictions

### Enable Diagnostic Logging

```javascript
const { setLogLevel } = require("@azure/logger");

// Enable verbose logging for debugging
setLogLevel("verbose");
```

## Additional Resources

- [Azure Key Vault for Node.js documentation](https://learn.microsoft.com/en-us/javascript/api/overview/azure/keyvault-secrets-readme)
- [DefaultAzureCredential documentation](https://learn.microsoft.com/en-us/javascript/api/@azure/identity/defaultazurecredential)
- [Managed Identity documentation](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Key Vault best practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
