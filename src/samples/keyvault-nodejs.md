# Azure Key Vault Integration - Node.js Sample

This document provides sample code for integrating Azure Key Vault with your Node.js application using Managed Identity.

## Prerequisites

Install the required Azure SDK packages:

```bash
npm install @azure/identity @azure/keyvault-secrets
```

## Configuration

Ensure your App Service has:
1. System-assigned managed identity enabled
2. Access policy configured in Key Vault (Get, List secrets)
3. `KEY_VAULT_URI` environment variable set (automatically configured by Bicep/Terraform)

## Sample Code

### Basic Usage - Retrieve a Secret

```javascript
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

async function getSecret(secretName) {
  try {
    // Get Key Vault URI from environment variable (set by App Service)
    const keyVaultUrl = process.env.KEY_VAULT_URI;
    
    if (!keyVaultUrl) {
      throw new Error('KEY_VAULT_URI environment variable is not set');
    }

    // Use DefaultAzureCredential - works with Managed Identity in Azure
    // and Azure CLI during local development
    const credential = new DefaultAzureCredential();
    
    // Create Key Vault client
    const client = new SecretClient(keyVaultUrl, credential);
    
    // Retrieve the secret
    const secret = await client.getSecret(secretName);
    
    console.log(`Successfully retrieved secret: ${secretName}`);
    return secret.value;
  } catch (error) {
    console.error(`Error retrieving secret ${secretName}:`, error.message);
    throw error;
  }
}

// Usage example
(async () => {
  try {
    const apiKey = await getSecret('api-key');
    console.log('API Key retrieved successfully');
    // Use the API key in your application
  } catch (error) {
    console.error('Failed to retrieve API key:', error);
  }
})();
```

### Advanced Usage - Key Vault Helper Module

Create a reusable module for Key Vault operations:

**File: `utils/keyvault.js`**

```javascript
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

class KeyVaultService {
  constructor() {
    const keyVaultUrl = process.env.KEY_VAULT_URI;
    
    if (!keyVaultUrl) {
      throw new Error('KEY_VAULT_URI environment variable is not set');
    }

    this.credential = new DefaultAzureCredential();
    this.client = new SecretClient(keyVaultUrl, this.credential);
    this.cache = new Map(); // Simple in-memory cache
  }

  /**
   * Retrieve a secret from Key Vault
   * @param {string} secretName - The name of the secret
   * @param {boolean} useCache - Whether to use cached value (default: true)
   * @returns {Promise<string>} The secret value
   */
  async getSecret(secretName, useCache = true) {
    try {
      // Check cache first
      if (useCache && this.cache.has(secretName)) {
        console.log(`Using cached value for secret: ${secretName}`);
        return this.cache.get(secretName);
      }

      // Retrieve from Key Vault
      const secret = await this.client.getSecret(secretName);
      
      // Cache the value
      this.cache.set(secretName, secret.value);
      
      console.log(`Retrieved secret from Key Vault: ${secretName}`);
      return secret.value;
    } catch (error) {
      console.error(`Error retrieving secret ${secretName}:`, error.message);
      throw error;
    }
  }

  /**
   * List all secrets in the Key Vault (names only, not values)
   * @returns {Promise<Array<string>>} Array of secret names
   */
  async listSecrets() {
    try {
      const secretNames = [];
      
      for await (const secretProperties of this.client.listPropertiesOfSecrets()) {
        secretNames.push(secretProperties.name);
      }
      
      console.log(`Found ${secretNames.length} secrets in Key Vault`);
      return secretNames;
    } catch (error) {
      console.error('Error listing secrets:', error.message);
      throw error;
    }
  }

  /**
   * Clear the secret cache
   */
  clearCache() {
    this.cache.clear();
    console.log('Secret cache cleared');
  }

  /**
   * Remove a specific secret from cache
   * @param {string} secretName - The name of the secret to remove from cache
   */
  removeCachedSecret(secretName) {
    this.cache.delete(secretName);
    console.log(`Removed cached secret: ${secretName}`);
  }
}

// Export singleton instance
module.exports = new KeyVaultService();
```

**Usage in your application:**

```javascript
const keyVaultService = require('./utils/keyvault');

// Example: Get database connection string
async function connectToDatabase() {
  try {
    const connectionString = await keyVaultService.getSecret('sql-connection-string');
    
    // Use the connection string to connect to your database
    // Example with mssql package:
    // const sql = require('mssql');
    // await sql.connect(connectionString);
    
    console.log('Connected to database successfully');
  } catch (error) {
    console.error('Database connection failed:', error);
  }
}

// Example: Get API keys
async function getApiKeys() {
  try {
    const openaiKey = await keyVaultService.getSecret('openai-api-key');
    const geminiKey = await keyVaultService.getSecret('gemini-api-key');
    
    return {
      openai: openaiKey,
      gemini: geminiKey
    };
  } catch (error) {
    console.error('Failed to retrieve API keys:', error);
    throw error;
  }
}

// Example: List all secrets
async function listAllSecrets() {
  try {
    const secretNames = await keyVaultService.listSecrets();
    console.log('Available secrets:', secretNames);
  } catch (error) {
    console.error('Failed to list secrets:', error);
  }
}
```

### Integration with Express.js

Add Key Vault secrets to your Express application:

```javascript
const express = require('express');
const keyVaultService = require('./utils/keyvault');

const app = express();

// Middleware to load secrets on startup
async function loadSecrets() {
  try {
    console.log('Loading secrets from Key Vault...');
    
    // Load required secrets
    process.env.OPENAI_API_KEY = await keyVaultService.getSecret('openai-api-key');
    process.env.GEMINI_API_KEY = await keyVaultService.getSecret('gemini-api-key');
    process.env.DEEPSEEK_API_KEY = await keyVaultService.getSecret('deepseek-api-key');
    
    // Optional: Load SQL password if not using connection string
    // process.env.SQL_PASSWORD = await keyVaultService.getSecret('sql-admin-password');
    
    console.log('All secrets loaded successfully');
  } catch (error) {
    console.error('Failed to load secrets:', error);
    // Decide whether to exit or continue with limited functionality
    // process.exit(1);
  }
}

// Load secrets before starting the server
loadSecrets().then(() => {
  const PORT = process.env.PORT || 3000;
  
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}).catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
});

// Example API endpoint that uses secrets
app.post('/api/gateway', async (req, res) => {
  const { service, prompt } = req.body;
  
  try {
    let apiKey;
    
    // Get API key from environment (loaded from Key Vault)
    switch (service) {
      case 'openai':
        apiKey = process.env.OPENAI_API_KEY;
        break;
      case 'gemini':
        apiKey = process.env.GEMINI_API_KEY;
        break;
      case 'deepseek':
        apiKey = process.env.DEEPSEEK_API_KEY;
        break;
      default:
        return res.status(400).json({ error: 'Invalid service' });
    }
    
    if (!apiKey) {
      // If key not found in env, try loading from Key Vault directly
      apiKey = await keyVaultService.getSecret(`${service}-api-key`);
    }
    
    // Use the API key to make request to AI service
    // ... your AI service logic here ...
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error in API gateway:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## Local Development

For local development with Azure CLI authentication:

1. Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
2. Login to Azure: `az login`
3. Set the Key Vault URI as an environment variable:
   ```bash
   export KEY_VAULT_URI="https://your-keyvault-name.vault.azure.net/"
   ```
4. Run your application: `npm start`

`DefaultAzureCredential` will automatically use your Azure CLI credentials locally.

## Environment Variables

The following environment variables are used:

- `KEY_VAULT_URI`: The URI of your Azure Key Vault (automatically set by deployment)

## Error Handling

Always implement proper error handling when accessing Key Vault:

```javascript
async function safeGetSecret(secretName, fallbackValue = null) {
  try {
    return await keyVaultService.getSecret(secretName);
  } catch (error) {
    console.error(`Failed to retrieve secret ${secretName}, using fallback:`, error.message);
    return fallbackValue;
  }
}

// Usage
const apiKey = await safeGetSecret('optional-api-key', 'default-key');
```

## Security Best Practices

1. **Never log secret values**: Only log secret names and success/failure status
2. **Use caching wisely**: Cache secrets to reduce Key Vault calls, but refresh periodically
3. **Handle secret rotation**: Implement logic to handle secret rotation gracefully
4. **Validate secrets**: Check that retrieved secrets are not empty or invalid
5. **Fail securely**: Decide whether to fail fast or use fallback values when secrets are unavailable

## Additional Resources

- [Azure Key Vault SDK for JavaScript](https://docs.microsoft.com/en-us/javascript/api/overview/azure/key-vault-secrets-readme)
- [DefaultAzureCredential Documentation](https://docs.microsoft.com/en-us/javascript/api/@azure/identity/defaultazurecredential)
- [Managed Identity Overview](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)

---

**Note**: This sample code is for demonstration purposes. Adapt it to your specific application requirements and security policies.
