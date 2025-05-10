# Health Dashboard Frontend

A React-based dashboard to monitor the health of Azure services through the health check API.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Get the API key from Key Vault and update `.env`:
```bash
# Get API key
API_KEY=$(az keyvault secret show --name health-api-key --vault-name kv-genai-dev-az203 --query value -o tsv)

# Update .env (on macOS)
sed -i '' "s/your-api-key-here/$API_KEY/" .env
```

4. Start the development server:
```bash
npm start
```

## Build for Production

```bash
npm run build
```

## Docker Build

```bash
docker build -t health-dashboard .
docker run -p 3000:3000 health-dashboard
```

## Features

- Real-time health status monitoring
- Automatic refresh every 30 seconds
- Status indicators for each service:
  - 🟢 Healthy
  - 🔴 Unhealthy
  - 🟡 Unknown
- Latency metrics
- Error reporting
