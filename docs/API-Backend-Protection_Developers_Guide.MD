# Protecting Backend Services with Google Cloud Endpoints: A Developer's Guide

## Introduction

This guide will walk you through the process of setting up Google Cloud Endpoints to protect your backend services in a Google Kubernetes Engine (GKE) environment. Cloud Endpoints provides a robust API management system that helps you secure, monitor, and control access to your APIs without needing to modify your existing code.

> **Important Note:** Google Cloud Endpoints with ESPv2 requires OpenAPI 2.0 (formerly Swagger) for API specifications. OpenAPI 3.0 is not currently supported.

## What will be Cover

- Basic Cloud Endpoints concepts
- Setting up authentication for your APIs
- Deploying Cloud Endpoints with your services
- Configuring rate limiting and quotas
- Monitoring your protected APIs

## Prerequisites

- A Google Cloud account
- Basic familiarity with Kubernetes concepts
- A backend service you want to protect
- A Google Cloud service account with appropriate permissions

## Step 1: Understanding the Architecture

Google Cloud Endpoints uses the **Extensible Service Proxy v2 (ESPv2)** to intercept and validate API requests before they reach your backend service.

Think of ESPv2 as a security guard that stands in front of your service:

```
Client Request → ESPv2 Proxy → Your Backend Service
                     ↓
              Security Checks
                     ↓
             Only valid requests
                 proceed
```

ESPv2 can run in two ways:
- As a **sidecar container** (runs alongside your service)
- As a **standalone container** (sits in front of your service)

## Step 2: Setting Up Your API Specification

First, create an OpenAPI 2.0 (formerly Swagger) specification file that describes your API. This tells Cloud Endpoints what your API looks like and how to secure it.

> **OpenAPI 2.0 Limitations:**
> - Limited support for content negotiation
> - Less flexible schema definitions compared to OpenAPI 3.0


Create a file named `openapi.yaml`:

```yaml
swagger: '2.0'
info:
  title: My Backend API
  description: API for my awesome service
  version: 1.0.0
host: my-api.endpoints.[YOUR-PROJECT-ID].cloud.goog
schemes:
  - https
produces:
  - application/json
paths:
  /hello:
    get:
      summary: Say hello
      operationId: hello
      responses:
        '200':
          description: A successful response
          schema:
            type: string
```

## Step 3: Adding Authentication

### Option 1: Simple API Key Authentication

Add this to your `openapi.yaml`:

```yaml
securityDefinitions:
  api_key:
    type: apiKey
    name: x-api-key
    in: header
security:
  - api_key: []
```

This requires all API requests to include a valid API key in the `x-api-key` header.

### Option 2: JWT Authentication (for user login)

For apps that require user login:

```yaml
securityDefinitions:
  jwt_auth:
    authorizationUrl: ""
    flow: "implicit"
    type: "oauth2"
    x-google-issuer: "https://accounts.google.com"
    x-google-jwks_uri: "https://www.googleapis.com/oauth2/v3/certs"
    x-google-audiences: "YOUR_CLIENT_ID"

security:
  - jwt_auth: []
```

### Option 3: Firebase Authentication (for mobile/web apps)

If you're using Firebase for authentication:

```yaml
securityDefinitions:
  firebase:
    authorizationUrl: ""
    flow: "implicit"
    type: "oauth2"
    x-google-issuer: "https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID"
    x-google-jwks_uri: "https://www.googleapis.com/service_accounts/v1/metadata/x509/securetoken@system.gserviceaccount.com"

security:
  - firebase: []
```

## Step 4: Protecting Specific Endpoints

You can apply different security to different endpoints:

```yaml
paths:
  /public:
    get:
      security: [] # No auth required
      responses:
        '200':
          description: Public endpoint
  
  /protected:
    get:
      security:
        - api_key: [] # API key required
      responses:
        '200':
          description: Protected endpoint
  
  /admin:
    get:
      security:
        - jwt_auth: ["admin"] # JWT with admin scope required
      responses:
        '200':
          description: Admin endpoint
```

## Step 5: Adding Rate Limiting

Prevent abuse by adding rate limits:

```yaml
quota:
  limits:
    - name: "RequestsPerMinutePerProject"
      metric: "serviceruntime.googleapis.com/api/consumer/request_count"
      unit: "1/min/{project}"
      values:
        STANDARD: 100 # 100 requests per minute
```

## Step 6: Setting Up Service Account Permissions

Before deploying, you need to set up a service account with the proper permissions if you dont have one already:

```bash
# Create a service account for Cloud Endpoints
gcloud iam service-accounts create endpoints-sa --display-name="Cloud Endpoints Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding [YOUR-PROJECT-ID] \
  --member="serviceAccount:endpoints-sa@[YOUR-PROJECT-ID].iam.gserviceaccount.com" \
  --role="roles/servicemanagement.serviceController"

# Create and download a key for the service account
gcloud iam service-accounts keys create endpoints-sa-key.json \
  --iam-account=endpoints-sa@[YOUR-PROJECT-ID].iam.gserviceaccount.com
```

The service account needs these permissions to:
- Register and manage API services
- Validate API keys and credentials
- Report metrics and logs to Google Cloud

## Step 7: Deploying to GKE

### Step 7.1: Deploy Your API Specification

```bash
gcloud endpoints services deploy openapi.yaml
```

This registers your API with Cloud Endpoints.

### Step 7.2: Create a Kubernetes Deployment

Create a file named `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-api
  template:
    metadata:
      labels:
        app: my-api
    spec:
      containers:
      # This is the ESPv2 sidecar container
      - name: esp
        image: gcr.io/endpoints-release/endpoints-runtime:2
        args: [
          "--http_port=8080",
          "--backend=127.0.0.1:8081",
          "--service=my-api.endpoints.[YOUR-PROJECT-ID].cloud.goog",
          "--rollout_strategy=managed"
        ]
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: service-account
          mountPath: /etc/endpoints/service-account
          readOnly: true
        env:
        - name: ENDPOINTS_SERVICE_PATH
          value: "/etc/endpoints/service-account/endpoints-sa-key.json"
      
      # This is your actual backend service
      - name: backend
        image: gcr.io/[YOUR-PROJECT-ID]/my-backend:latest
        ports:
        - containerPort: 8081
      

```


### Step 7.3: Create a Kubernetes Service

Create a file named `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-api
spec:
  type: ClusterIP
  selector:
    app: my-api
  ports:
  - port: 80
    targetPort: 8080
```

### Step 7.4 Create a Kubernetes Ingress 
Create a file named `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
    rules:
    - host: my-api.endpoints.[YOUR-PROJECT-ID].cloud.goog # Or your custom domain
        http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: my-api
                port:
                  number: 80
        

### Step 7.5: Deploy Everything

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Step 8: Creating API Keys

Create an API key for developers to use:

```bash
gcloud services api-keys create --display-name="Developer API Key"
```

Note the returned key value. This is what developers will include in their `x-api-key` header.

## Step 9: Testing Your Protected API

```bash
# This should fail (no API key)
curl -i https://[YOUR_ENDPOINT_IP]/hello

# This should succeed (with valid API key)
curl -i -H "x-api-key: YOUR_API_KEY" https://[YOUR_ENDPOINT_IP]/hello
```

## Step 10: Monitoring Your API

1. Go to the Google Cloud Console
2. Navigate to "Endpoints" > "Services"
3. Select your API service
4. View the dashboard for:
   - Request volume
   - Error rates
   - Latency statistics
   - API key usage

## Common Troubleshooting

### Problem: "Authentication failed" errors
- Check that the API key is correct and active
- Verify the header name is exactly `x-api-key` (case sensitive)

### Problem: ESPv2 container not starting
- Check the container logs: `kubectl logs [pod-name] -c esp`
- Verify your service name matches what you deployed to Endpoints

### Problem: Service account permission issues
- Verify the service account has the correct roles assigned


### Problem: Rate limiting issues
- Check quota settings in your OpenAPI spec
- Look at the `X-RateLimit-*` headers in the response

---

This guide covered the basics of protecting your backends with Google Cloud Endpoints. As you grow more comfortable with the system, explore the additional configuration options to build a robust API security strategy tailored to your specific needs.

## Additional Resources

- [Google Cloud Endpoints Documentation](https://cloud.google.com/endpoints/docs)
- [OpenAPI Specification](https://swagger.io/specification/)
- [ESPv2 Configuration Options](https://cloud.google.com/endpoints/docs/openapi/specify-proxy-startup-options)