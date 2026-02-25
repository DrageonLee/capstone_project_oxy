###############################################################################
# Embedding Module — Main
###############################################################################

locals {
  function_name = "embed-bedrock-titan"
  lambda_zip    = "${path.module}/../../../ingestion/embed_lambda.zip"
}

# ── IAM Role for Lambda ───────────────────────────────────────────────────────

resource "aws_iam_role" "embed_lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "embed_lambda" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.embed_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadCorpus"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.corpus_bucket}/${var.corpus_key}"
      },
      {
        Sid      = "WriteEmbeddings"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${var.output_bucket}/${var.output_prefix}*"
      },
      {
        Sid      = "BedrockEmbed"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.function_name}:*"
      }
    ]
  })
}

# ── Lambda Function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "embed" {
  function_name    = local.function_name
  role             = aws_iam_role.embed_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512
  filename         = local.lambda_zip
  source_code_hash = filebase64sha256(local.lambda_zip)

  environment {
    variables = {
      CORPUS_BUCKET = var.corpus_bucket
      CORPUS_KEY    = var.corpus_key
      OUTPUT_BUCKET = var.output_bucket
      OUTPUT_PREFIX = var.output_prefix
      MODEL_ID      = var.model_id
      BATCH_SIZE    = tostring(var.batch_size)
      MAX_RETRIES   = tostring(var.max_retries)
    }
  }

  tags = var.tags
}

# ── IAM Role for Step Functions ───────────────────────────────────────────────

resource "aws_iam_role" "sfn" {
  name = "${local.function_name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sfn" {
  name = "${local.function_name}-sfn-policy"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.embed.arn
    }]
  })
}

# ── Step Functions State Machine ──────────────────────────────────────────────

resource "aws_sfn_state_machine" "embed" {
  name     = "${local.function_name}-pipeline"
  role_arn = aws_iam_role.sfn.arn

  definition = templatefile(
    "${path.module}/../../../ingestion/state_machine.json",
    { embed_lambda_arn = aws_lambda_function.embed.arn }
  )

  tags = var.tags
}
