# Azure Key Vault Integration with Node.js

This document demonstrates how to integrate Azure Key Vault with your Node.js application to securely retrieve secrets, keys, and certificates.

## Prerequisites

- Azure Key Vault instance created
- App Service with Managed Identity enabled (automatically configured by Bicep/Terraform templates)
- Node.js application

## Installation

Install the required Azure SDK packages:

```bash
npm install @azure/identity @azure/keyvault-secrets
```

## Basic Usage

### 1. Using DefaultAzureCredential (Recommended)

`DefaultAzureCredential` automatically handles authentication using Managed Identity in Azure or other credentials locally.

```javascript
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

// Initialize credential
const credential = new DefaultAzureCredential();

// Get Key Vault URL from environment variable
const vaultUrl = process.env.KEY_VAULT_URI || 'https://your-keyvault.vault.azure.net/';

// Create SecretClient
const client = new SecretClient(vaultUrl, credential);

// Retrieve a secret
async function getSecret(secretName) {
  try {
    const secret = await client.getSecret(secretName);
    console.log(`Secret value: ${secret.value}`);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    throw error;
  }
}

// Example: Get SQL connection string
getSecret('SqlConnectionString')
  .then(connectionString => {
    // Use the connection string
    console.log('Successfully retrieved SQL connection string');
  })
  .catch(error => {
    console.error('Failed to retrieve secret:', error);
  });
```

### 2. List All Secrets

```javascript
async function listSecrets() {
  console.log('Listing all secrets:');
  
  for await (const secretProperties of client.listPropertiesOfSecrets()) {
    console.log(`- ${secretProperties.name}`);
  }
}

listSecrets();
```

### 3. Set a New Secret (requires write permissions)

```javascript
async function setSecret(secretName, secretValue) {
  try {
    const secret = await client.setSecret(secretName, secretValue);
    console.log(`Secret ${secretName} set successfully`);
    return secret;
  } catch (error) {
    console.error(`Error setting secret ${secretName}:`, error.message);
    throw error;
  }
}

// Example
setSecret('ApiKey', 'my-secret-api-key-12345');
```

### 4. Update Secret Properties

```javascript
async function updateSecretMetadata(secretName, tags) {
  try {
    const secretProperties = await client.getSecret(secretName);
    secretProperties.properties.tags = tags;
    await client.updateSecretProperties(secretName, secretProperties.properties.version, {
      tags: tags
    });
    console.log(`Updated metadata for ${secretName}`);
  } catch (error) {
    console.error(`Error updating secret metadata:`, error.message);
    throw error;
  }
}

// Example
updateSecretMetadata('ApiKey', { environment: 'production', owner: 'dev-team' });
```

## Integration with Express.js

### Complete Example: Express App with Key Vault

```javascript
const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Key Vault client
const credential = new DefaultAzureCredential();
const vaultUrl = process.env.KEY_VAULT_URI;
let secretClient;

if (vaultUrl) {
  secretClient = new SecretClient(vaultUrl, credential);
  console.log(`Key Vault client initialized with URL: ${vaultUrl}`);
} else {
  console.warn('KEY_VAULT_URI not set. Key Vault integration disabled.');
}

// Helper function to get secrets
async function getSecretValue(secretName) {
  if (!secretClient) {
    throw new Error('Key Vault client not initialized');
  }
  
  try {
    const secret = await secretClient.getSecret(secretName);
    return secret.value;
  } catch (error) {
    console.error(`Failed to retrieve secret ${secretName}:`, error.message);
    throw error;
  }
}

// Middleware to load secrets on startup
async function loadSecretsMiddleware() {
  if (!secretClient) return;
  
  try {
    // Load critical secrets at startup
    process.env.SQL_CONNECTION_STRING = await getSecretValue('SqlConnectionString');
    console.log('✓ SQL connection string loaded from Key Vault');
    
    // Load API keys if they exist
    try {
      process.env.DEEPSEEK_API_KEY = await getSecretValue('DeepSeekApiKey');
      console.log('✓ DeepSeek API key loaded from Key Vault');
    } catch (e) {
      console.log('⚠ DeepSeek API key not found in Key Vault');
    }
    
    try {
      process.env.GEMINI_API_KEY = await getSecretValue('GeminiApiKey');
      console.log('✓ Gemini API key loaded from Key Vault');
    } catch (e) {
      console.log('⚠ Gemini API key not found in Key Vault');
    }
    
  } catch (error) {
    console.error('Error loading secrets from Key Vault:', error.message);
    // Don't fail the app if Key Vault is unavailable
  }
}

// API endpoint to retrieve a secret (with proper authorization)
app.get('/api/secret/:name', async (req, res) => {
  // Add authentication/authorization here
  if (!req.headers.authorization) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  try {
    const secretValue = await getSecretValue(req.params.name);
    // Never return the actual secret value to the client
    res.json({ 
      success: true, 
      message: `Secret ${req.params.name} retrieved successfully` 
    });
  } catch (error) {
    res.status(500).json({ 
      error: 'Failed to retrieve secret',
      message: error.message 
    });
  }
});

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    keyVault: 'not configured'
  };
  
  if (secretClient) {
    try {
      // Test Key Vault connectivity
      await secretClient.listPropertiesOfSecrets().next();
      health.keyVault = 'connected';
    } catch (error) {
      health.keyVault = 'error: ' + error.message;
      health.status = 'degraded';
    }
  }
  
  res.json(health);
});

// Start server
async function startServer() {
  // Load secrets before starting the server
  await loadSecretsMiddleware();
  
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

startServer();
```

## Best Practices

### 1. Use Managed Identity

Always use Managed Identity in Azure for authentication - no need to manage credentials:

```javascript
// ✅ Good - Uses Managed Identity
const credential = new DefaultAzureCredential();

// ❌ Bad - Hard-coded credentials (NEVER do this)
const credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
```

### 2. Cache Secrets

Cache secrets in memory to reduce Key Vault calls and improve performance:

```javascript
class SecretCache {
  constructor(secretClient, ttlSeconds = 3600) {
    this.secretClient = secretClient;
    this.cache = new Map();
    this.ttl = ttlSeconds * 1000;
  }
  
  async getSecret(secretName) {
    const cached = this.cache.get(secretName);
    
    if (cached && Date.now() - cached.timestamp < this.ttl) {
      console.log(`Cache hit for ${secretName}`);
      return cached.value;
    }
    
    console.log(`Cache miss for ${secretName}, fetching from Key Vault`);
    const secret = await this.secretClient.getSecret(secretName);
    
    this.cache.set(secretName, {
      value: secret.value,
      timestamp: Date.now()
    });
    
    return secret.value;
  }
  
  invalidate(secretName) {
    this.cache.delete(secretName);
  }
  
  invalidateAll() {
    this.cache.clear();
  }
}

// Usage
const cache = new SecretCache(secretClient, 1800); // 30 minute TTL
const apiKey = await cache.getSecret('ApiKey');
```

### 3. Handle Errors Gracefully

```javascript
async function getSecretSafely(secretName, defaultValue = null) {
  try {
    const secret = await client.getSecret(secretName);
    return secret.value;
  } catch (error) {
    if (error.statusCode === 404) {
      console.warn(`Secret ${secretName} not found, using default`);
      return defaultValue;
    }
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    return defaultValue;
  }
}

// Usage
const apiKey = await getSecretSafely('OptionalApiKey', 'default-key');
```

### 4. Use Environment Variables for Key Vault URI

Never hard-code the Key Vault URI:

```javascript
// ✅ Good
const vaultUrl = process.env.KEY_VAULT_URI;

// ❌ Bad
const vaultUrl = 'https://my-keyvault.vault.azure.net/';
```

### 5. Minimize Key Vault Calls

Load secrets once at application startup, not on every request:

```javascript
// ✅ Good - Load once at startup
let dbConnectionString;

async function initialize() {
  dbConnectionString = await getSecret('SqlConnectionString');
}

initialize().then(() => {
  app.listen(PORT);
});

// ❌ Bad - Load on every request
app.get('/data', async (req, res) => {
  const dbConnectionString = await getSecret('SqlConnectionString'); // Expensive!
  // ...
});
```

## Local Development

For local development without Azure Managed Identity:

### Option 1: Azure CLI

Ensure you're logged in with Azure CLI:

```bash
az login
```

`DefaultAzureCredential` will automatically use your Azure CLI credentials.

### Option 2: Environment Variables

For local testing, use environment variables:

```javascript
// In development, fall back to environment variables
const getConfig = async (secretName, envVar) => {
  if (process.env.NODE_ENV === 'production' && secretClient) {
    return await getSecretValue(secretName);
  } else {
    return process.env[envVar];
  }
};

// Usage
const sqlConnectionString = await getConfig('SqlConnectionString', 'SQL_CONNECTION_STRING');
```

### Option 3: Local Secrets File (Development Only)

```javascript
// secrets.dev.js (add to .gitignore!)
module.exports = {
  SqlConnectionString: 'Server=localhost;Database=dev;...',
  ApiKey: 'dev-api-key'
};

// app.js
const getSecret = process.env.NODE_ENV === 'production'
  ? async (name) => (await secretClient.getSecret(name)).value
  : async (name) => require('./secrets.dev.js')[name];
```

## Troubleshooting

### Error: "Authentication failed"

- Ensure Managed Identity is enabled on App Service
- Verify the App Service identity has access to Key Vault
- Check Key Vault access policies

### Error: "Secret not found"

- Verify the secret name is correct (case-sensitive)
- Check the secret exists in Key Vault
- Ensure the secret is enabled (not disabled)

### Error: "Access denied"

- Check Key Vault access policies include your App Service principal
- Verify the correct permissions are granted (Get, List for secrets)

## Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [@azure/keyvault-secrets npm package](https://www.npmjs.com/package/@azure/keyvault-secrets)
- [@azure/identity npm package](https://www.npmjs.com/package/@azure/identity)
- [Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

---

**Security Note**: Never log or return actual secret values in production. Always handle secrets securely and follow the principle of least privilege.
