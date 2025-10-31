# Azure Key Vault Integration for Node.js

This document provides code samples for integrating Azure Key Vault with your Node.js application.

## Prerequisites

Install the Azure SDK for Key Vault:

```bash
npm install @azure/keyvault-secrets @azure/identity
```

## Using Managed Identity (Recommended for Azure App Service)

When running on Azure App Service or Azure Functions with Managed Identity enabled, use `DefaultAzureCredential`:

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

// Key Vault URL from environment variable or configuration
const keyVaultName = process.env.KEY_VAULT_NAME || "your-keyvault-name";
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

// Create a client using DefaultAzureCredential
// This will automatically use Managed Identity when running in Azure
const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUrl, credential);

// Function to get a secret from Key Vault
async function getSecret(secretName) {
  try {
    const secret = await client.getSecret(secretName);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    throw error;
  }
}

// Example: Get Application Insights connection string
async function getAppInsightsConnectionString() {
  return await getSecret("APPINSIGHTS-CONNECTION-STRING");
}

// Example: Get database connection string
async function getDatabaseConnectionString() {
  return await getSecret("DATABASE-CONNECTION-STRING");
}

// Example: Get API keys
async function getApiKey(serviceName) {
  return await getSecret(`${serviceName}-API-KEY`);
}

module.exports = {
  getSecret,
  getAppInsightsConnectionString,
  getDatabaseConnectionString,
  getApiKey
};
```

## Integration with Express Server

Update your `server.js` to load secrets on startup:

```javascript
const express = require('express');
const { getSecret, getAppInsightsConnectionString } = require('./keyvault-helper');

const app = express();
const PORT = process.env.PORT || 3000;

// Store secrets loaded from Key Vault
let appSecrets = {};

async function initializeSecrets() {
  try {
    console.log('Loading secrets from Azure Key Vault...');
    
    // Load Application Insights connection string
    if (process.env.NODE_ENV === 'production') {
      appSecrets.appInsightsConnectionString = await getAppInsightsConnectionString();
      console.log('Application Insights connection string loaded');
    }
    
    // Load other secrets as needed
    // appSecrets.dbConnectionString = await getDatabaseConnectionString();
    // appSecrets.apiKey = await getApiKey('deepseek');
    
    console.log('All secrets loaded successfully');
  } catch (error) {
    console.error('Failed to load secrets from Key Vault:', error);
    // Decide whether to continue without secrets or exit
    if (process.env.NODE_ENV === 'production') {
      process.exit(1); // Exit in production if secrets can't be loaded
    }
  }
}

async function startServer() {
  // Initialize secrets before starting the server
  await initializeSecrets();
  
  // Your Express routes and middleware here
  app.get('/', (req, res) => {
    res.send('Application is running');
  });
  
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

// Start the server
startServer().catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
```

## Using Service Principal (for Local Development)

For local development, use a Service Principal:

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { ClientSecretCredential } = require("@azure/identity");

const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

// Load service principal credentials from environment variables
const credential = new ClientSecretCredential(
  process.env.AZURE_TENANT_ID,
  process.env.AZURE_CLIENT_ID,
  process.env.AZURE_CLIENT_SECRET
);

const client = new SecretClient(keyVaultUrl, credential);

async function getSecret(secretName) {
  const secret = await client.getSecret(secretName);
  return secret.value;
}
```

## Environment Variables Configuration

### For Local Development (.env file):

```bash
# Azure Key Vault
KEY_VAULT_NAME=your-keyvault-name

# Service Principal (for local development)
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
```

### For Azure App Service:

Application Settings (set via Azure Portal or CLI):

```bash
KEY_VAULT_NAME=your-keyvault-name
# No need for service principal credentials - use Managed Identity
```

Or use Key Vault references directly in App Settings:

```bash
APPINSIGHTS_CONNECTION_STRING=@Microsoft.KeyVault(SecretUri=https://your-keyvault.vault.azure.net/secrets/APPINSIGHTS-CONNECTION-STRING/)
DATABASE_CONNECTION_STRING=@Microsoft.KeyVault(SecretUri=https://your-keyvault.vault.azure.net/secrets/DATABASE-CONNECTION-STRING/)
```

## Setting Secrets in Key Vault

### Using Azure CLI:

```bash
# Set a secret
az keyvault secret set \
  --vault-name your-keyvault-name \
  --name "APPINSIGHTS-CONNECTION-STRING" \
  --value "InstrumentationKey=xxx;IngestionEndpoint=https://xxx"

# Get a secret
az keyvault secret show \
  --vault-name your-keyvault-name \
  --name "APPINSIGHTS-CONNECTION-STRING"

# List all secrets
az keyvault secret list \
  --vault-name your-keyvault-name
```

### Using Azure Portal:

1. Navigate to your Key Vault in Azure Portal
2. Go to "Secrets" in the left menu
3. Click "+ Generate/Import"
4. Enter the secret name and value
5. Click "Create"

## Grant Access to Key Vault

### Grant App Service Managed Identity access:

```bash
# Get the App Service principal ID
PRINCIPAL_ID=$(az webapp identity show \
  --name your-app-name \
  --resource-group your-rg-name \
  --query principalId -o tsv)

# Grant access to Key Vault
az keyvault set-policy \
  --name your-keyvault-name \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

### Grant Service Principal access (for local development):

```bash
az keyvault set-policy \
  --name your-keyvault-name \
  --spn your-client-id \
  --secret-permissions get list
```

## Error Handling Best Practices

```javascript
async function getSecretSafely(secretName, defaultValue = null) {
  try {
    const secret = await client.getSecret(secretName);
    return secret.value;
  } catch (error) {
    if (error.code === 'SecretNotFound') {
      console.warn(`Secret ${secretName} not found, using default value`);
      return defaultValue;
    }
    
    if (error.code === 'Forbidden') {
      console.error(`Access denied to secret ${secretName}. Check permissions.`);
      throw error;
    }
    
    console.error(`Error retrieving secret ${secretName}:`, error);
    throw error;
  }
}
```

## Caching Secrets

To avoid hitting Key Vault on every request, cache secrets in memory:

```javascript
class SecretCache {
  constructor(ttlMinutes = 60) {
    this.cache = new Map();
    this.ttl = ttlMinutes * 60 * 1000; // Convert to milliseconds
  }
  
  set(key, value) {
    this.cache.set(key, {
      value,
      timestamp: Date.now()
    });
  }
  
  get(key) {
    const cached = this.cache.get(key);
    if (!cached) return null;
    
    if (Date.now() - cached.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return cached.value;
  }
  
  clear() {
    this.cache.clear();
  }
}

const secretCache = new SecretCache(60); // Cache for 60 minutes

async function getCachedSecret(secretName) {
  let secret = secretCache.get(secretName);
  
  if (!secret) {
    secret = await getSecret(secretName);
    secretCache.set(secretName, secret);
  }
  
  return secret;
}
```

## Additional Resources

- [Azure Key Vault Node.js SDK Documentation](https://docs.microsoft.com/en-us/javascript/api/@azure/keyvault-secrets/)
- [Azure Identity Node.js SDK Documentation](https://docs.microsoft.com/en-us/javascript/api/@azure/identity/)
- [Managed Identities for Azure Resources](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
