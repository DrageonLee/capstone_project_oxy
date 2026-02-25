#!/usr/bin/env python3
"""
Create a KNN vector index on an OpenSearch Serverless collection.

Called by Terraform null_resource local-exec provisioner.
Uses opensearch-py with AWS SigV4 authentication.

Dependencies (install before running):
  pip install opensearch-py requests-aws4auth boto3
"""

import argparse
import json
import sys
import time

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth


def get_aws_auth(region: str) -> AWS4Auth:
    """Create SigV4 auth from default credentials chain."""
    credentials = boto3.Session().get_credentials().get_frozen_credentials()
    return AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        region,
        "aoss",
        session_token=credentials.token,
    )


def create_client(endpoint: str, region: str) -> OpenSearch:
    """Create OpenSearch client for Serverless (AOSS)."""
    # Strip https:// prefix if present
    host = endpoint.replace("https://", "").replace("http://", "")

    return OpenSearch(
        hosts=[{"host": host, "port": 443}],
        http_auth=get_aws_auth(region),
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection,
        timeout=60,
    )


def build_index_body(args: argparse.Namespace) -> dict:
    """Build the index mapping for knn_vector."""
    return {
        "settings": {
            "index": {
                "number_of_shards": 1,
                "number_of_replicas": 0,
                "knn": True,
                "knn.algo_param.ef_search": args.ef_search,
            }
        },
        "mappings": {
            "properties": {
                "embedding": {
                    "type": "knn_vector",
                    "dimension": args.dimension,
                    "method": {
                        "name": "hnsw",
                        "engine": args.engine,
                        "space_type": args.space_type,
                        "parameters": {
                            "m": args.hnsw_m,
                            "ef_construction": args.ef_construction,
                        },
                    },
                },
                "text": {"type": "text"},
                "doc_id": {"type": "keyword"},
                "title": {"type": "text"},
                "url": {"type": "keyword"},
                "chunk_id": {"type": "keyword"},
                "metadata": {
                    "type": "object",
                    "enabled": True,
                },
            }
        },
    }


def wait_for_collection(client: OpenSearch, index_name: str, max_retries: int = 30) -> None:
    """Wait until the collection endpoint is responsive.
    
    Note: cluster.health() is NOT supported on OpenSearch Serverless.
    We use a lightweight indices.exists() call instead.
    """
    for attempt in range(max_retries):
        try:
            # indices.exists() works on Serverless and returns True/False
            client.indices.exists(index=index_name)
            print(f"  Collection is responsive (attempt {attempt + 1})")
            return
        except Exception as e:
            if "403" in str(e) or "Forbidden" in str(e):
                raise PermissionError(
                    f"Access denied (403). Check data access policy includes your IAM principal. Error: {e}"
                )
            print(f"  Waiting for collection... (attempt {attempt + 1}/{max_retries}): {e}")
            time.sleep(10)
    raise TimeoutError("Collection did not become responsive within timeout")


def main():
    parser = argparse.ArgumentParser(description="Create OpenSearch Serverless vector index")
    parser.add_argument("--endpoint", required=True, help="Collection endpoint URL")
    parser.add_argument("--index-name", required=True, help="Index name")
    parser.add_argument("--dimension", type=int, required=True, help="Vector dimension")
    parser.add_argument("--engine", default="faiss", help="ANN engine (faiss/nmslib)")
    parser.add_argument("--space-type", default="cosinesimil", help="Distance metric")
    parser.add_argument("--hnsw-m", type=int, default=16, help="HNSW M parameter")
    parser.add_argument("--ef-construction", type=int, default=512, help="HNSW ef_construction")
    parser.add_argument("--ef-search", type=int, default=512, help="HNSW ef_search")
    parser.add_argument("--region", default=None, help="AWS region (auto-detected if omitted)")
    args = parser.parse_args()

    # Auto-detect region
    region = args.region or boto3.Session().region_name
    if not region:
        print("ERROR: Unable to determine AWS region. Set --region or AWS_DEFAULT_REGION.")
        sys.exit(1)

    print(f"Creating vector index '{args.index_name}' on {args.endpoint}")
    print(f"  dimension={args.dimension}, engine={args.engine}, space_type={args.space_type}")
    print(f"  hnsw_m={args.hnsw_m}, ef_construction={args.ef_construction}, ef_search={args.ef_search}")

    client = create_client(args.endpoint, region)

    # Wait for collection to be responsive
    print("Waiting for collection to be responsive...")
    wait_for_collection(client, args.index_name)

    # Check if index already exists
    if client.indices.exists(index=args.index_name):
        print(f"Index '{args.index_name}' already exists — skipping creation.")
        sys.exit(0)

    # Create the index
    index_body = build_index_body(args)
    print(f"Index body:\n{json.dumps(index_body, indent=2)}")

    response = client.indices.create(index=args.index_name, body=index_body)
    print(f"Index created successfully: {response}")


if __name__ == "__main__":
    main()
