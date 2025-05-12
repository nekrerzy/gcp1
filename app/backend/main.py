from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Optional
import os
import logging
from datetime import datetime
import json
import time

# Google Cloud SDK imports
from google.cloud import storage
from google.cloud import documentai_v1 as documentai
from google.cloud import firestore
from google.cloud import secretmanager
from google.cloud import aiplatform
from vertexai.generative_models import GenerativeModel
import vertexai
        

import google.auth
from google.cloud.sql.connector import Connector, IPTypes
import sqlalchemy
import pg8000

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Google Cloud Services Health Check API")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Get project information from metadata
_, PROJECT_ID = google.auth.default()
PROJECT_NUMBER = os.environ.get("PROJECT_NUMBER")
REGION = os.environ.get("REGION", "us-central1")
LOCATION = os.environ.get("LOCATION", "us")  # Global location for some services


class HealthStatus(BaseModel):
    status: str
    latency_ms: float
    timestamp: str
    error: Optional[str] = None
    details: Optional[Dict] = None


def log_health_check(service: str, status: HealthStatus):
    """Log health check results to Cloud Logging"""
    properties = {
        "service": service,
        "status": status.status,
        "latency_ms": status.latency_ms,
        "error": status.error,
        "details": json.dumps(status.details) if status.details else None,
    }

    if status.status == "unhealthy":
        logger.error(f"Health check failed for {service}", extra=properties)
    else:
        logger.info(f"Health check passed for {service}", extra=properties)


async def check_cloud_storage():
    start_time = datetime.now()
    try:
        # Create a client using default credentials
        storage_client = storage.Client()
        
        # List buckets to verify access
        buckets = list(storage_client.list_buckets(max_results=1))

        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details={"buckets": [bucket.name for bucket in buckets]},
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("cloud_storage", status)
    return status


async def check_document_ai():
    start_time = datetime.now()
    try:
        # Initialize Document AI client
        client = documentai.DocumentProcessorServiceClient()
        
        # List processors to verify access
        parent = f"projects/{PROJECT_ID}/locations/{LOCATION}"
        request = documentai.ListProcessorsRequest(parent=parent, page_size=1)
        processors = client.list_processors(request=request)
        
        # Get the first processor if available
        processor_list = list(processors)
        details = {"processors_available": len(processor_list) > 0}
        
        # If a processor exists, use its name for additional detail
        if processor_list and len(processor_list) > 0:
            details["sample_processor"] = processor_list[0].name
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details=details,
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("document_ai", status)
    return status


async def check_firestore():
    start_time = datetime.now()
    try:
        # Initialize Firestore client
        db = firestore.Client(database="prod-firestore")
        
        # Create a test collection reference
        health_collection = db.collection("health_checks")
        
        # Write a test document
        doc_ref = health_collection.document("test_health_check")
        doc_ref.set({
            "timestamp": datetime.now().isoformat(),
            "source": "health_check_api"
        })
        
        # Read the document back
        doc = doc_ref.get()
        doc_data = doc.to_dict()
        
        # Clean up - delete the test document
        doc_ref.delete()
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details={"read_test": "successful", "write_test": "successful", "data": str(doc_data)}
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("firestore", status)
    return status


async def check_secret_manager():
    start_time = datetime.now()
    try:
        # Initialize Secret Manager client
        client = secretmanager.SecretManagerServiceClient()
        
        # List secrets to verify access
        parent = f"projects/{PROJECT_ID}"
        secrets = list(client.list_secrets(request={"parent": parent, "page_size": 1}))
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details={"secrets_available": len(secrets) > 0}
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("secret_manager", status)
    return status


async def check_vertex_ai_gemini():
    start_time = datetime.now()
    try:
         # Initialize Vertex AI
        vertexai.init(project=PROJECT_ID, location=REGION)
        
        # Create a model object
        model = GenerativeModel("gemini-2.0-flash")
        
        # Generate content
        response = model.generate_content("What is Google Cloud Platform?")
        
        # Extract response text
        output_text = response.text if hasattr(response, "text") else str(response)
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details={"response": output_text[:100] + "..." if len(output_text) > 100 else output_text}
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("vertex_ai_gemini", status)
    return status



async def check_vertex_ai_index():
    start_time = datetime.now()
    try:
        # Initialize Vertex AI
        aiplatform.init(project=PROJECT_ID, location=REGION)
        
        # Use the Index API directly
        client_options = {"api_endpoint": f"{REGION}-aiplatform.googleapis.com"}
        index_client = aiplatform.gapic.IndexServiceClient(client_options=client_options)
        
        # List indexes to verify access
        parent = f"projects/{PROJECT_ID}/locations/{REGION}"
        
        # Execute the request
        response = index_client.list_indexes(parent=parent)
        indexes = list(response)
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details={"indexes_count": len(indexes)}
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
        )

    log_health_check("vertex_ai_index", status)
    return status


async def check_cloud_sql():
    start_time = datetime.now()
    connector = None
    details = {}
    
    try:
        # Use Secret Manager to get connection info
        secret_client = secretmanager.SecretManagerServiceClient()
        
        # Get connection details from Secret Manager
        instance_secret_name = f"projects/{PROJECT_ID}/secrets/db-instance-connection-name/versions/latest"
        db_user_secret_name = f"projects/{PROJECT_ID}/secrets/db-user/versions/latest"
        db_pass_secret_name = f"projects/{PROJECT_ID}/secrets/db-password/versions/latest"
        db_name_secret_name = f"projects/{PROJECT_ID}/secrets/db-name/versions/latest"
        
        instance_connection_name = secret_client.access_secret_version(request={"name": instance_secret_name}).payload.data.decode("UTF-8")
        db_user = secret_client.access_secret_version(request={"name": db_user_secret_name}).payload.data.decode("UTF-8")
        db_pass = secret_client.access_secret_version(request={"name": db_pass_secret_name}).payload.data.decode("UTF-8")
        db_name = secret_client.access_secret_version(request={"name": db_name_secret_name}).payload.data.decode("UTF-8")
        
        details["db_name"] = db_name
        details["instance"] = instance_connection_name
        
        # Initialize the connector
        connector = Connector()
        
        # Function to get a connection to Cloud SQL
        def getconn():
            return connector.connect(
                instance_connection_name,
                "pg8000",
                user=db_user,
                password=db_pass,
                db=db_name,
                ip_type=IPTypes.PRIVATE
            )
        
        # Create SQLAlchemy engine using the connector
        engine = sqlalchemy.create_engine(
            "postgresql+pg8000://",
            creator=getconn,
        )
        
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
        
        status = HealthStatus(
            status="healthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            details=details,
        )
    except Exception as e:
        status = HealthStatus(
            status="unhealthy",
            latency_ms=(datetime.now() - start_time).total_seconds() * 1000,
            timestamp=datetime.now().isoformat(),
            error=str(e),
            details=details,
        )
    finally:
        if connector:
            connector.close()

    log_health_check("cloud_sql", status)
    return status


@app.get("/health")
async def health_check() -> Dict[str, HealthStatus]:
    """
    Perform health checks on all Google Cloud services.
    Returns the status of each service with latency information.
    """
    services = {
        "cloud_storage": check_cloud_storage(),
        "document_ai": check_document_ai(),
        "firestore": check_firestore(),
        "secret_manager": check_secret_manager(),
        "vertex_ai_gemini": check_vertex_ai_gemini(),
        "vertex_ai_index": check_vertex_ai_index(),
        "cloud_sql": check_cloud_sql(),
    }

    results = {}
    overall_status = "healthy"

    for service_name, check_coroutine in services.items():
        try:
            results[service_name] = await check_coroutine
            if results[service_name].status == "unhealthy":
                overall_status = "unhealthy"
        except Exception as e:
            logger.exception(f"Unexpected error in {service_name} health check")
            results[service_name] = HealthStatus(
                status="unhealthy",
                latency_ms=0,
                timestamp=datetime.now().isoformat(),
                error=f"Unexpected error: {str(e)}",
            )
            overall_status = "unhealthy"

    # Log overall health status
    logger.info(
        "Overall health check status",
        extra={
            "overall_status": overall_status,
            "service_statuses": {k: v.status for k, v in results.items()},
        },
    )

    return results


@app.get("/")
async def root():
    """
    Root endpoint returning basic service information.
    """
    return {
        "service": "Google Cloud Services Health Check API",
        "version": "1.0.0",
        "health_endpoint": "/health",
    }


@app.get("/status-0123456789abcdef")
async def probe_status():
    """
    Simple health probe for liveness and readiness checks.
    Used by Cloud Run or GKE probes.
    """
    return {"status": "ok"}