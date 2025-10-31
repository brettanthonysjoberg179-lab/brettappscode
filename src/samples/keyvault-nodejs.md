# Azure Key Vault Integration Sample for Node.js

This sample demonstrates how to integrate Azure Key Vault with a Node.js application using the Azure SDK and managed identities. This approach provides secure secret management without storing credentials in code or configuration files.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Authentication Methods](#authentication-methods)
5. [Code Examples](#code-examples)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

## Overview

Azure Key Vault is a cloud service for securely storing and accessing secrets, keys, and certificates. This sample shows how to:

- Authenticate using **Managed Identity** (recommended for Azure-hosted apps)
- Authenticate using **DefaultAzureCredential** (works locally and in Azure)
- Retrieve secrets from Key Vault
- Handle errors and implement retry logic
- Cache secrets for performance

## Prerequisites

### Azure Resources

- Azure Key Vault instance
- System-assigned or user-assigned managed identity (for Azure-hosted applications)
- Key Vault access policy or RBAC role assignment

### Local Development

- Node.js 14.x or higher
- Azure CLI installed and authenticated (`az login`)
- Azure SDK packages

### Required Permissions

Grant the managed identity or service principal the following role:
- **Key Vault Secrets User** (for reading secrets)

## Installation

Install the required Azure SDK packages:

```bash
npm install @azure/keyvault-secrets @azure/identity
```

### Package Descriptions

- `@azure/keyvault-secrets`: Client library for Azure Key Vault secrets
- `@azure/identity`: Authentication library supporting multiple credential types

## Authentication Methods

### 1. Managed Identity (Production - Recommended)

**Best for Azure-hosted applications** (App Service, Azure Functions, AKS, VMs):

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { ManagedIdentityCredential } = require("@azure/identity");

const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

// Use managed identity for authentication
const credential = new ManagedIdentityCredential();
const client = new SecretClient(keyVaultUrl, credential);
```

### 2. DefaultAzureCredential (Development & Production)

**Best for applications that run both locally and in Azure:**

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;

// DefaultAzureCredential tries multiple authentication methods:
// 1. EnvironmentCredential (for service principals)
// 2. ManagedIdentityCredential (for Azure-hosted apps)
// 3. AzureCliCredential (for local development)
// 4. Others...
const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUrl, credential);
```

### 3. Service Principal (CI/CD Pipelines)

**For automated deployments and pipelines:**

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { ClientSecretCredential } = require("@azure/identity");

const keyVaultUrl = `https://${process.env.KEY_VAULT_NAME}.vault.azure.net`;

const credential = new ClientSecretCredential(
  process.env.AZURE_TENANT_ID,
  process.env.AZURE_CLIENT_ID,
  process.env.AZURE_CLIENT_SECRET
);

const client = new SecretClient(keyVaultUrl, credential);
```

## Code Examples

### Basic: Get a Single Secret

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

async function getSecret(secretName) {
  const keyVaultName = process.env.KEY_VAULT_NAME;
  const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
  
  const credential = new DefaultAzureCredential();
  const client = new SecretClient(keyVaultUrl, credential);
  
  try {
    const secret = await client.getSecret(secretName);
    console.log(`Secret retrieved: ${secretName}`);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret: ${error.message}`);
    throw error;
  }
}

// Usage
getSecret("ApiKey").then(apiKey => {
  console.log("API Key retrieved successfully");
  // Use the API key in your application
});
```

### Advanced: Secret Manager Class

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

class SecretManager {
  constructor(keyVaultName) {
    this.keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
    this.credential = new DefaultAzureCredential();
    this.client = new SecretClient(this.keyVaultUrl, this.credential);
    this.cache = new Map(); // In-memory cache
    this.cacheTTL = 300000; // 5 minutes
  }

  async getSecret(secretName, useCache = true) {
    // Check cache first
    if (useCache && this.cache.has(secretName)) {
      const cached = this.cache.get(secretName);
      if (Date.now() - cached.timestamp < this.cacheTTL) {
        console.log(`Using cached secret: ${secretName}`);
        return cached.value;
      }
    }

    try {
      console.log(`Fetching secret from Key Vault: ${secretName}`);
      const secret = await this.client.getSecret(secretName);
      
      // Cache the secret
      this.cache.set(secretName, {
        value: secret.value,
        timestamp: Date.now()
      });
      
      return secret.value;
    } catch (error) {
      console.error(`Error retrieving secret ${secretName}: ${error.message}`);
      throw error;
    }
  }

  async getSecrets(secretNames) {
    const promises = secretNames.map(name => this.getSecret(name));
    return Promise.all(promises);
  }

  async setSecret(secretName, secretValue) {
    try {
      console.log(`Setting secret: ${secretName}`);
      await this.client.setSecret(secretName, secretValue);
      
      // Invalidate cache
      this.cache.delete(secretName);
      
      console.log(`Secret ${secretName} set successfully`);
    } catch (error) {
      console.error(`Error setting secret ${secretName}: ${error.message}`);
      throw error;
    }
  }

  clearCache() {
    this.cache.clear();
    console.log("Cache cleared");
  }
}

// Usage
const secretManager = new SecretManager(process.env.KEY_VAULT_NAME);

async function main() {
  try {
    // Get a single secret
    const apiKey = await secretManager.getSecret("ApiKey");
    console.log("API Key retrieved");

    // Get multiple secrets
    const [dbPassword, apiSecret] = await secretManager.getSecrets([
      "DatabasePassword",
      "ApiSecret"
    ]);
    console.log("Multiple secrets retrieved");

    // Set a new secret (requires Key Vault Secrets Officer role)
    // await secretManager.setSecret("NewSecret", "SecretValue123");
    
  } catch (error) {
    console.error("Error:", error);
  }
}

main();
```

### Integration with Express.js

```javascript
const express = require("express");
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");

const app = express();
const port = process.env.PORT || 3000;

// Initialize Key Vault client
const keyVaultName = process.env.KEY_VAULT_NAME;
const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
const credential = new DefaultAzureCredential();
const secretClient = new SecretClient(keyVaultUrl, credential);

// Cache for secrets
const secretCache = new Map();
const CACHE_TTL = 300000; // 5 minutes

async function getSecret(secretName) {
  // Check cache
  if (secretCache.has(secretName)) {
    const cached = secretCache.get(secretName);
    if (Date.now() - cached.timestamp < CACHE_TTL) {
      return cached.value;
    }
  }

  // Fetch from Key Vault
  try {
    const secret = await secretClient.getSecret(secretName);
    secretCache.set(secretName, {
      value: secret.value,
      timestamp: Date.now()
    });
    return secret.value;
  } catch (error) {
    console.error(`Error fetching secret ${secretName}:`, error.message);
    throw error;
  }
}

// Middleware to load secrets on startup
async function loadSecrets() {
  try {
    // Load required secrets at startup
    const apiKey = await getSecret("ApiKey");
    const dbConnectionString = await getSecret("DatabaseConnectionString");
    
    // Store in app.locals for access in routes
    app.locals.apiKey = apiKey;
    app.locals.dbConnectionString = dbConnectionString;
    
    console.log("Secrets loaded successfully");
  } catch (error) {
    console.error("Failed to load secrets:", error);
    process.exit(1); // Exit if critical secrets can't be loaded
  }
}

// Routes
app.get("/", (req, res) => {
  res.json({ message: "API is running", status: "ok" });
});

app.get("/api/config", async (req, res) => {
  try {
    // Retrieve a secret dynamically
    const apiKey = await getSecret("ApiKey");
    
    res.json({
      hasApiKey: !!apiKey,
      keyVault: keyVaultName,
      status: "configured"
    });
  } catch (error) {
    res.status(500).json({ error: "Failed to retrieve configuration" });
  }
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    keyVault: keyVaultName,
    secretsLoaded: !!app.locals.apiKey
  });
});

// Start server after loading secrets
loadSecrets()
  .then(() => {
    app.listen(port, () => {
      console.log(`Server running on port ${port}`);
      console.log(`Key Vault: ${keyVaultName}`);
    });
  })
  .catch(error => {
    console.error("Failed to start server:", error);
    process.exit(1);
  });
```

### Database Connection String Example

```javascript
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");
const { Connection } = require("tedious"); // SQL Server client

async function connectToDatabase() {
  const keyVaultName = process.env.KEY_VAULT_NAME;
  const keyVaultUrl = `https://${keyVaultName}.vault.azure.net`;
  
  const credential = new DefaultAzureCredential();
  const client = new SecretClient(keyVaultUrl, credential);
  
  try {
    // Get connection string from Key Vault
    const secret = await client.getSecret("DatabaseConnectionString");
    const connectionString = secret.value;
    
    // Parse connection string (format: Server=...;Database=...;User ID=...;Password=...)
    const config = parseConnectionString(connectionString);
    
    // Create database connection
    const connection = new Connection(config);
    
    connection.on("connect", err => {
      if (err) {
        console.error("Database connection failed:", err);
      } else {
        console.log("Connected to database successfully");
      }
    });
    
    connection.connect();
    return connection;
    
  } catch (error) {
    console.error("Error connecting to database:", error.message);
    throw error;
  }
}

function parseConnectionString(connectionString) {
  const parts = connectionString.split(";");
  const config = {};
  
  parts.forEach(part => {
    const [key, value] = part.split("=");
    if (key && value) {
      config[key.trim()] = value.trim();
    }
  });
  
  return {
    server: config.Server,
    authentication: {
      type: "default",
      options: {
        userName: config["User ID"],
        password: config.Password
      }
    },
    options: {
      database: config.Database,
      encrypt: true
    }
  };
}
```

## Best Practices

### 1. Use Managed Identity in Production

Always use managed identity for Azure-hosted applications. No credentials to manage!

### 2. Cache Secrets

Avoid calling Key Vault on every request. Cache secrets with a reasonable TTL (5-15 minutes).

### 3. Handle Errors Gracefully

```javascript
async function getSecretSafely(secretName, defaultValue = null) {
  try {
    return await secretManager.getSecret(secretName);
  } catch (error) {
    console.warn(`Failed to get secret ${secretName}, using default`);
    return defaultValue;
  }
}
```

### 4. Implement Retry Logic

```javascript
async function getSecretWithRetry(secretName, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await secretManager.getSecret(secretName);
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      console.log(`Retry ${i + 1}/${maxRetries} for secret ${secretName}`);
      await sleep(1000 * Math.pow(2, i)); // Exponential backoff
    }
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
```

### 5. Use Environment Variables for Key Vault Name

Never hardcode the Key Vault name:

```javascript
// Good
const keyVaultName = process.env.KEY_VAULT_NAME;

// Bad
const keyVaultName = "my-keyvault-prod"; // Don't hardcode
```

### 6. Separate Secrets by Environment

Use different Key Vaults for dev, staging, and production:

- `myapp-kv-dev`
- `myapp-kv-staging`
- `myapp-kv-prod`

### 7. Monitor Access

Enable Key Vault diagnostics and send logs to Log Analytics or Application Insights.

## Troubleshooting

### Error: "AuthenticationError: No managed identity endpoint found"

**Cause:** Running locally without Azure CLI authentication, or managed identity not enabled.

**Solution:**
```bash
# For local development, login with Azure CLI
az login

# For App Service, enable managed identity
az webapp identity assign --name <APP_NAME> --resource-group <RG_NAME>
```

### Error: "Access denied"

**Cause:** Managed identity doesn't have permissions to access Key Vault.

**Solution:**
```bash
# Get managed identity principal ID
PRINCIPAL_ID=$(az webapp identity show --name <APP_NAME> --resource-group <RG_NAME> --query principalId -o tsv)

# Grant access using RBAC
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.KeyVault/vaults/<KV_NAME>
```

### Error: "Secret not found"

**Cause:** Secret doesn't exist in Key Vault or was deleted.

**Solution:**
```bash
# List secrets
az keyvault secret list --vault-name <KV_NAME>

# Create secret
az keyvault secret set --vault-name <KV_NAME> --name "ApiKey" --value "your-secret-value"
```

### Performance Issues

**Cause:** Calling Key Vault too frequently.

**Solution:** Implement caching (see [Advanced Example](#advanced-secret-manager-class)).

## Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure SDK for JavaScript](https://github.com/Azure/azure-sdk-for-js)
- [@azure/keyvault-secrets Package](https://www.npmjs.com/package/@azure/keyvault-secrets)
- [@azure/identity Package](https://www.npmjs.com/package/@azure/identity)
- [Managed Identities Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

## License

This sample code is provided under the MIT License.

---

**Last Updated:** 2025-10-31  
**Version:** 1.0.0
