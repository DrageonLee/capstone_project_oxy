"""
embed_lambda/handler.py
-----------------------
Lambda handler: reads a batch of chunks from corpus.json on S3,
calls Bedrock Titan Embeddings V2, writes results back to S3.

Invoked by Step Functions Map state — one Lambda call per batch.

Environment variables:
    CORPUS_BUCKET   S3 bucket containing corpus.json     (required)
    CORPUS_KEY      S3 key for corpus.json               (default: processed/corpus.json)
    OUTPUT_BUCKET   S3 bucket for embeddings output      (default: same as CORPUS_BUCKET)
    OUTPUT_PREFIX   S3 prefix for embedding files        (default: embeddings/)
    MODEL_ID        Bedrock model ID                     (default: amazon.titan-embed-text-v2:0)
    BATCH_SIZE      Documents per Lambda invocation      (default: 25)
    MAX_RETRIES     Bedrock API retry attempts           (default: 3)

Step Functions event input:
    {
        "batch_index": 0,      # which batch this Lambda handles
        "batch_size": 25       # optional override
    }
"""

import json
import logging
import math
import os
import time

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── Config from environment ────────────────────────────────────────────────────

CORPUS_BUCKET = os.environ["CORPUS_BUCKET"]
CORPUS_KEY    = os.environ.get("CORPUS_KEY", "processed/corpus.json")
OUTPUT_BUCKET = os.environ.get("OUTPUT_BUCKET", CORPUS_BUCKET)
OUTPUT_PREFIX = os.environ.get("OUTPUT_PREFIX", "embeddings/")
MODEL_ID      = os.environ.get("MODEL_ID", "amazon.titan-embed-text-v2:0")
BATCH_SIZE    = int(os.environ.get("BATCH_SIZE", "25"))
MAX_RETRIES   = int(os.environ.get("MAX_RETRIES", "3"))
REGION        = os.environ.get("AWS_REGION", "us-east-1")

# ── AWS clients ────────────────────────────────────────────────────────────────

s3      = boto3.client("s3", region_name=REGION)
bedrock = boto3.client("bedrock-runtime", region_name=REGION)


def load_corpus() -> list[dict]:
    """Load corpus.json from S3. Expected schema: {id, title, url, text}"""
    logger.info("Loading corpus from s3://%s/%s", CORPUS_BUCKET, CORPUS_KEY)
    response = s3.get_object(Bucket=CORPUS_BUCKET, Key=CORPUS_KEY)
    corpus   = json.loads(response["Body"].read().decode("utf-8"))
    logger.info("Corpus loaded — %d documents", len(corpus))
    return corpus


def get_batch(corpus: list[dict], batch_index: int, batch_size: int) -> list[dict]:
    start = batch_index * batch_size
    end   = start + batch_size
    batch = corpus[start:end]
    logger.info("Batch %d: docs %d-%d (%d total)", batch_index, start, min(end, len(corpus)) - 1, len(batch))
    return batch


def embed_text(text: str) -> list[float]:
    """Call Bedrock Titan Embeddings V2 with exponential backoff on throttling."""
    body = json.dumps({"inputText": text})

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = bedrock.invoke_model(
                modelId     = MODEL_ID,
                body        = body,
                contentType = "application/json",
                accept      = "application/json",
            )
            return json.loads(response["body"].read())["embedding"]

        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in ("ThrottlingException", "ServiceUnavailableException"):
                wait = 2 ** attempt  # 2s, 4s, 8s
                logger.warning("Bedrock throttled (attempt %d/%d). Retrying in %ds…", attempt, MAX_RETRIES, wait)
                if attempt < MAX_RETRIES:  # 마지막 시도에서는 sleep 불필요
                    time.sleep(wait)
            else:
                logger.error("Bedrock error: %s", e)
                raise

    raise RuntimeError(f"Bedrock call failed after {MAX_RETRIES} retries")


def embed_batch(docs: list[dict]) -> list[dict]:
    results = []
    for doc in docs:
        doc_id = doc.get("id", "unknown")
        text   = doc.get("text", "")

        if not text.strip():
            logger.warning("Skipping empty doc: %s", doc_id)
            continue

        embedding = embed_text(text)
        results.append({
            "doc_id"   : doc_id,
            "chunk_id" : doc.get("chunk_id", doc_id),
            "title"    : doc.get("title", ""),
            "url"      : doc.get("url", ""),
            "text"     : text,
            "embedding": embedding,
        })

    return results


def save_embeddings(batch_index: int, records: list[dict]) -> str:
    key  = f"{OUTPUT_PREFIX.rstrip('/')}/batch_{batch_index:04d}.json"
    body = json.dumps(records, ensure_ascii=False)
    s3.put_object(Bucket=OUTPUT_BUCKET, Key=key, Body=body.encode("utf-8"), ContentType="application/json")
    logger.info("Saved %d embeddings → s3://%s/%s", len(records), OUTPUT_BUCKET, key)
    return key


def lambda_handler(event: dict, context) -> dict:
    """
    Entry point called by Step Functions Map state.

    Event input:  {"batch_index": 0, "batch_size": 25}
    Returns:      {"batch_index": 0, "output_key": "...", "docs_embedded": 25, "total_batches": 9}
    """
    batch_index = int(event.get("batch_index", 0))
    batch_size  = int(event.get("batch_size", BATCH_SIZE))

    corpus        = load_corpus()
    total_batches = math.ceil(len(corpus) / batch_size)

    if batch_index >= total_batches:
        logger.warning("batch_index %d >= total_batches %d — nothing to do.", batch_index, total_batches)
        return {"batch_index": batch_index, "output_key": None, "docs_embedded": 0, "total_batches": total_batches}

    batch      = get_batch(corpus, batch_index, batch_size)
    records    = embed_batch(batch)
    output_key = save_embeddings(batch_index, records)

    return {
        "batch_index"  : batch_index,
        "output_key"   : output_key,
        "docs_embedded": len(records),
        "total_batches": total_batches,
    }
