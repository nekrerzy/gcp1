# Developer Guide: Connecting to Google Cloud Services

This guide explains how to connect to various Google Cloud services in your application using service account authentication via Workload Identity. All services are configured to use GCP authentication, eliminating the need for API keys or connection strings in your code.

## Authentication with Workload Identity

When running in a Google Kubernetes Engine (GKE) cluster with Workload Identity enabled, your application will automatically authenticate to Google Cloud services using the Kubernetes service account associated with your pod. This provides several benefits:

1. **No credential management**: No need to manually create, download, or rotate service account keys
2. **Enhanced security**: Service account credentials never leave Google's infrastructure
3. **Simplified code**: Your application code doesn't need to handle authentication explicitly
4. **Fine-grained access control**: Different pods can have different permissions

All the code examples in this guide rely on this automatic authentication mechanism. When you run your application in a properly configured GKE pod, the Google client libraries will automatically:

1. Detect that they're running in GKE
2. Obtain the identity of the Kubernetes service account
3. Exchange it for a Google service account token
4. Use this token to authenticate to Google Cloud services

No additional configuration is required in your code to enable this authentication flow.

## Prerequisites

1. Install required Python packages:
```bash
# FastAPI and web server
pip install fastapi>=0.104.0 uvicorn>=0.23.2 pydantic>=2.4.2

# Google Cloud libraries
pip install google-cloud-storage>=2.12.0 google-cloud-documentai>=2.23.0 
pip install google-cloud-firestore>=2.13.1 google-cloud-secret-manager>=2.16.3
pip install google-cloud-aiplatform>=1.38.0 google-cloud-aiplatform[prediction]>=1.38.0
pip install vertexai>=1.38.0 google-auth>=2.23.3

# Database connections
pip install cloud-sql-python-connector>=1.4.0 sqlalchemy>=2.0.23 pg8000>=1.30.1

# Logging and monitoring
pip install google-cloud-logging>=3.8.0

# Utilities
pip install python-dateutil>=2.8.2 asyncio>=3.4.3
```

Alternatively, you can install all requirements at once using a requirements.txt file:

2. Environment Variables (provided by infrastructure):
```bash
# Core project settings
PROJECT_ID=your-gcp-project-id
PROJECT_NUMBER=your-gcp-project-number
REGION=us-central1
LOCATION=us

# Service-specific settings (optional)
BUCKET_NAME=your-storage-bucket
DOC_AI_PROCESSOR_ID=your-docai-processor-id
CLOUD_SQL_INSTANCE=your-cloudsql-instance
```

## Service Connections

### 1. Cloud Storage

```python
from google.cloud import storage
import os

def get_storage_client():
    # Default credentials are automatically used
    project_id = os.environ.get("PROJECT_ID")
    return storage.Client(project=project_id)

# Example: Upload a file
def upload_file(bucket_name: str, blob_name: str, data: bytes):
    client = get_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    blob.upload_from_string(data)
    
# Example: Download a file
async def download_file(bucket_name: str, blob_name: str):
    client = get_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    return blob.download_as_bytes()

# Example: List files in a bucket
async def list_files(bucket_name: str, prefix: str = None):
    client = get_storage_client()
    bucket = client.bucket(bucket_name)
    blobs = bucket.list_blobs(prefix=prefix)
    return [blob.name for blob in blobs]
```

### 2. Document AI

```python
from google.cloud import documentai_v1 as documentai
import os

def get_document_ai_client():
    return documentai.DocumentProcessorServiceClient()

# Example: Process document
async def process_document(processor_id: str, file_content: bytes, mime_type: str = "application/pdf"):
    client = get_document_ai_client()
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("LOCATION", "us")
    
    # Format the processor name
    processor_name = f"projects/{project_id}/locations/{location}/processors/{processor_id}"
    
    # Create the document object
    raw_document = documentai.RawDocument(
        content=file_content,
        mime_type=mime_type
    )
    
    # Configure the process request
    request = documentai.ProcessRequest(
        name=processor_name,
        raw_document=raw_document
    )
    
    # Process the document
    result = client.process_document(request=request)
    return result.document

# Example: Get document text
def get_document_text(document):
    return document.text

# Example: Get document entities
def get_document_entities(document):
    entities = []
    for entity in document.entities:
        entities.append({
            "type": entity.type_,
            "mention_text": entity.mention_text,
            "confidence": entity.confidence
        })
    return entities
```

### 3. Vertex AI with Gemini

```python
from vertexai.generative_models import GenerativeModel
import vertexai
import os

def get_gemini_model():
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("REGION", "us-central1")
    
    # Initialize Vertex AI
    vertexai.init(project=project_id, location=location)
    
    # Get the model
    return GenerativeModel("gemini-2.0-flash")

# Example: Generate text with Gemini
def generate_text(prompt: str):
    model = get_gemini_model()
    response = model.generate_content(prompt)
    return response.text
```

### 4. Vertex AI Vector Search

```python
from google.cloud import aiplatform
import os

def get_vector_search_client():
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("REGION", "us-central1")
    
    # Initialize Vertex AI
    aiplatform.init(project=project_id, location=location)
    
    # Create client options specific to this region
    client_options = {"api_endpoint": f"{location}-aiplatform.googleapis.com"}
    
    # Get the index service client
    return aiplatform.gapic.IndexServiceClient(client_options=client_options)

# Example: Query vector index
async def vector_search(index_endpoint_id: str, deployed_index_id: str, embedding_vector: list, num_neighbors: int = 10):
    # Get the client
    client = get_vector_search_client()
    
    # Get project details
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("REGION", "us-central1")
    
    # Format the endpoint full resource name
    endpoint_name = f"projects/{project_id}/locations/{location}/indexEndpoints/{index_endpoint_id}"
    
    # Create the query
    query = {
        "deployed_index_id": deployed_index_id,
        "queries": [embedding_vector],
        "neighbor_count": num_neighbors
    }
    
    # Perform the search
    response = client.find_neighbors(
        index_endpoint=endpoint_name,
        queries=[query]
    )
    
    # Process and return results
    results = []
    for batch in response.nearest_neighbors:
        for neighbor in batch.neighbors:
            results.append({
                "id": neighbor.datapoint.datapoint_id,
                "distance": neighbor.distance
            })
    
    return results

# Example: Get embeddings for vector search
async def get_embeddings(text: str):
    # Initialize Vertex AI
    project_id = os.environ.get("PROJECT_ID")
    location = os.environ.get("REGION", "us-central1")
    aiplatform.init(project=project_id, location=location)
    
    # Get the text embedding model
    model = aiplatform.TextEmbeddingModel.from_pretrained("text-embedding-005")
    
    # Generate embeddings
    embeddings = model.get_embeddings([text])
    
    # Return the first embedding vector
    return embeddings[0].values if embeddings and len(embeddings) > 0 else []
```

### 5. Firestore Database

```python
from google.cloud import firestore
import os

def get_firestore_client(database_id="dev-firestore"):
    # Create a client with the specified database
    return firestore.Client(database=database_id)

# Example: Get document
def get_document(collection: str, document_id: str, database_id="dev-firestore"):
    client = get_firestore_client(database_id)
    doc_ref = client.collection(collection).document(document_id)
    return doc_ref.get().to_dict()

# Example: Write document
def write_document(collection: str, document_id: str, data: dict, database_id="dev-firestore"):
    client = get_firestore_client(database_id)
    doc_ref = client.collection(collection).document(document_id)
    doc_ref.set(data)
    
# Example: Test Firestore connectivity
async def test_firestore_connectivity(database_id="dev-firestore"):
    try:
        # Initialize Firestore client
        db = firestore.Client(database=database_id)
        
        # Create a test collection reference
        health_collection = db.collection("health_checks")
        
        # Write a test document
        doc_ref = health_collection.document("test_health_check")
        timestamp = datetime.now().isoformat()
        doc_ref.set({
            "timestamp": timestamp,
            "source": "health_check_api"
        })
        
        # Read the document back
        doc = doc_ref.get()
        doc_data = doc.to_dict()
        
        # Clean up - delete the test document
        doc_ref.delete()
        
        return {
            "status": "healthy",
            "details": {
                "read_test": "successful", 
                "write_test": "successful", 
                "data": doc_data
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }
```

### 6. Cloud SQL (PostgreSQL)

```python
from google.cloud.sql.connector import Connector, IPTypes
import sqlalchemy
import pg8000
from google.cloud import secretmanager
import os

def get_cloud_sql_connection():
    # Initialize the connector
    connector = Connector()
    
    try:
        # Get Secret Manager client
        secret_client = secretmanager.SecretManagerServiceClient()
        project_id = os.environ.get("PROJECT_ID")
        
        # Get connection details from Secret Manager
        instance_secret_name = f"projects/{project_id}/secrets/db-instance-connection-name/versions/latest"
        db_user_secret_name = f"projects/{project_id}/secrets/db-user/versions/latest"
        db_pass_secret_name = f"projects/{project_id}/secrets/db-password/versions/latest"
        db_name_secret_name = f"projects/{project_id}/secrets/db-name/versions/latest"
        
        instance_connection_name = secret_client.access_secret_version(request={"name": instance_secret_name}).payload.data.decode("UTF-8")
        db_user = secret_client.access_secret_version(request={"name": db_user_secret_name}).payload.data.decode("UTF-8")
        db_pass = secret_client.access_secret_version(request={"name": db_pass_secret_name}).payload.data.decode("UTF-8")
        db_name = secret_client.access_secret_version(request={"name": db_name_secret_name}).payload.data.decode("UTF-8")
        
        # Function to get a connection to Cloud SQL
        def getconn():
            return connector.connect(
                instance_connection_name,
                "pg8000",
                user=db_user,
                password=db_pass,
                db=db_name,
                ip_type=IPTypes.PRIVATE  # Use private IP for VPC connectivity
            )
        
        # Create an SQLAlchemy engine using the connector
        engine = sqlalchemy.create_engine(
            "postgresql+pg8000://",
            creator=getconn,
        )
        
        return engine, connector
    except Exception as e:
        if connector:
            connector.close()
        raise e

# Example: Execute query
async def execute_query(query: str, params: dict = None):
    engine, connector = None, None
    try:
        engine, connector = get_cloud_sql_connection()
        with engine.connect() as conn:
            result = conn.execute(sqlalchemy.text(query), params)
            if query.lower().strip().startswith('select'):
                return [dict(row._mapping) for row in result]
            conn.commit()
    finally:
        if connector:
            connector.close()

# Example: Test database connectivity
async def test_database_connectivity():
    engine, connector = None, None
    details = {}
    
    try:
        engine, connector = get_cloud_sql_connection()
        
        # Test connection with a simple query
        with engine.connect() as conn:
            # Check version
            version_result = conn.execute(sqlalchemy.text("SELECT version()"))
            for row in version_result:
                details["version"] = row[0]
                
            # Create a test table if it doesn't exist
            conn.execute(sqlalchemy.text("""
                CREATE TABLE IF NOT EXISTS health_check_test (
                    id SERIAL PRIMARY KEY,
                    check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            # Insert a test row
            conn.execute(sqlalchemy.text("INSERT INTO health_check_test DEFAULT VALUES"))
            conn.commit()
            
            details["write_test"] = "passed"
        
        return {
            "status": "healthy",
            "details": details
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "details": details
        }
    finally:
        if connector:
            connector.close()
```

### 7. Secret Manager

```python
from google.cloud import secretmanager
import os

def get_secret_manager_client():
    return secretmanager.SecretManagerServiceClient()

# Example: Access secret
async def access_secret(secret_name: str, version: str = "latest"):
    client = get_secret_manager_client()
    project_id = os.environ.get("PROJECT_ID")
    
    # Build the resource name
    name = f"projects/{project_id}/secrets/{secret_name}/versions/{version}"
    
    # Access the secret version
    response = client.access_secret_version(request={"name": name})
    
    # Return the decoded payload
    return response.payload.data.decode("UTF-8")

# Example: Create a new secret
async def create_secret(secret_id: str, secret_data: str):
    client = get_secret_manager_client()
    project_id = os.environ.get("PROJECT_ID")
    
    # Build the parent resource name
    parent = f"projects/{project_id}"
    
    # Create the secret
    secret = client.create_secret(
        request={
            "parent": parent,
            "secret_id": secret_id,
            "secret": {"replication": {"automatic": {}}}
        }
    )
    
    # Add a version to the secret
    version = client.add_secret_version(
        request={
            "parent": secret.name,
            "payload": {"data": secret_data.encode("UTF-8")}
        }
    )
    
    return version.name

# Example: List all secrets
async def list_secrets():
    client = get_secret_manager_client()
    project_id = os.environ.get("PROJECT_ID")
    
    # Build the parent resource name
    parent = f"projects/{project_id}"
    
    # List all secrets
    secrets = client.list_secrets(request={"parent": parent})
    
    # Return the secret names
    return [secret.name for secret in secrets]
```

## Local Development

For local development, you'll need to set up authentication differently since you won't be running inside GKE:

1. **Application Default Credentials (ADC)**:
   ```bash
   gcloud auth application-default login
   ```
   This will store credentials in your local environment that the Google Cloud client libraries will use automatically.

2. **Service account impersonation**:
   ```bash
   gcloud config set auth/impersonate_service_account YOUR_SERVICE_ACCOUNT@YOUR_PROJECT.iam.gserviceaccount.com
   ```
   This allows you to impersonate the same service account that your application uses in GKE.

3. **Environment variable configuration**: Set the same environment variables locally that your pods use in GKE:
   ```bash
   export PROJECT_ID=your-gcp-project-id
   export PROJECT_NUMBER=your-gcp-project-number
   export REGION=us-central1
   export LOCATION=us
   ```

The code examples in this guide will work the same way in both local development and GKE environments because the Google Cloud client libraries automatically detect and use the appropriate credentials.

## Troubleshooting

1. **Authentication Issues**:
   - Ensure workload identity is properly configured
   - Verify IAM roles are correctly assigned
   - Check if your local gcloud session is authenticated
   - Run `gcloud auth application-default print-access-token` to validate credentials
   - Check logs for authentication errors with `kubectl logs <pod-name>`

2. **Connection Issues**:
   - Verify environment variables are correctly set
   - Check network connectivity and firewall rules
   - Ensure VPC Service Controls are properly configured
   - Test connectivity from your pod: `kubectl exec -it <pod-name> -- curl metadata.google.internal`
   - Verify DNS resolution is working: `kubectl exec -it <pod-name> -- nslookup storage.googleapis.com`

3. **Permission Issues**:
   - Review IAM role assignments in Google Cloud Console
   - Check if you need additional database-level permissions
   - Verify service-specific access policies
   - Check for "Permission denied" errors in Cloud Logging
   - Use the Policy Troubleshooter in Google Cloud Console to diagnose permission issues

4. **Service-Specific Issues**:
   - **Cloud Storage**: Check bucket permissions and access control
   - **Document AI**: Verify processor exists and is in the correct region
   - **Vertex AI**: Ensure models are deployed and available in your region
   - **Cloud SQL**: Check connection settings, IP allowlist, and SSL configuration
   - **Firestore**: Verify database mode (Native vs Datastore) and indexes

5. **Logging and Debugging**:
   ```python
   import logging
   from google.cloud import logging as cloud_logging
   
   # Setup Cloud Logging
   client = cloud_logging.Client()
   client.setup_logging()
   
   # Create a logger
   logger = logging.getLogger("my-application")
   
   # Log messages at different levels
   logger.debug("Detailed debugging information")
   logger.info("Informational message")
   logger.warning("Warning message")
   logger.error("Error message", exc_info=True)  # Include exception info
   ```

## Security Notes

1. Never store credentials in code or configuration files
2. Use workload identity for GKE pods to avoid service account key files
3. Follow the principle of least privilege for IAM roles
4. Keep dependencies updated for security patches
5. Use VPC Service Controls to restrict service access
6. Enable audit logging for all services
7. Implement a robust secrets management strategy with Secret Manager
8. Set up alerts for suspicious activity in Cloud Monitoring
9. Use Cloud Armor for web application firewall protection
10. Encrypt data at rest and in transit
11. Implement proper input validation to prevent injection attacks
12. Use Organization Policy Service to enforce security policies

