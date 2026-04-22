const { randomUUID } = require('node:crypto');

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
const { GetObjectCommand, PutObjectCommand, S3Client } = require('@aws-sdk/client-s3');
const { DynamoDBDocumentClient, PutCommand, QueryCommand } = require('@aws-sdk/lib-dynamodb');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);
const s3Client = new S3Client({});
const bedrockClient = new BedrockRuntimeClient({});

const TABLE_NAME = process.env.CVS_TABLE;
const BUCKET_NAME = process.env.CVS_BUCKET;
const HAIKU_MODEL_ID = 'anthropic.claude-3-haiku-20240307-v1:0';

const response = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(body),
});

const getUserId = (event) => event?.requestContext?.authorizer?.jwt?.claims?.sub;

const parseJson = (value) => {
  if (!value) {
    return null;
  }

  if (typeof value === 'object') {
    return value;
  }

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
};

const extractResumeJson = (bedrockResponseText) => {
  const cleaned = bedrockResponseText
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/, '')
    .trim();

  try {
    return JSON.parse(cleaned);
  } catch {
    return {
      rawText: cleaned,
      pdfLayout:
        'Use bold section headers, horizontal separators between sections, and a compact one-page layout.',
    };
  }
};

const buildResumePrompt = (
  cvData
) => `You are an expert resume writer. Your ONLY job is to transform the provided JSON data into natural language text for each resume section.

CRITICAL RULES:
1. ONLY include information that is EXPLICITLY provided in the input JSON
2. NEVER invent skills, achievements, technologies, or experiences that aren't in the input
3. If a field is empty or "Not provided", write "Not specified" - do NOT make anything up
4. Use the desired role description to CONTEXTUALIZE existing skills, but do NOT add new ones
5. Keep your output factual and strictly based on the input data

Input JSON structure to reference:
${JSON.stringify(cvData, null, 2)}

For each section:
- Header: Format as "Name | Location | Email | Phone | LinkedIn | GitHub" using only provided fields
- Summary: 2-3 sentences based ONLY on the provided information
- Experience: Transform each job entry, keeping only the achievements and metrics explicitly provided
- Skills: List ONLY the skills explicitly provided in the skills array
- Education, Certifications, Languages: Include only what's provided

Return a valid JSON object with these exact keys: Header, Summary, Experience, Skills, Education, Certifications, Languages, Additional, and pdfLayout.`;

const renderPseudoPdfContent = (name, structuredResume) => {
  const baseSections = [
    `CV: ${name}`,
    '',
    'HEADER',
    structuredResume.Header || structuredResume.header || '',
    '',
    'SUMMARY',
    structuredResume.Summary || structuredResume.summary || '',
    '',
    'PROFESSIONAL EXPERIENCE',
    structuredResume.Experience || structuredResume.experience || '',
    '',
    'SKILLS',
    structuredResume.Skills || structuredResume.skills || '',
    '',
    'EDUCATION',
    structuredResume.Education || structuredResume.education || '',
    '',
    'CERTIFICATIONS',
    structuredResume.Certifications || structuredResume.certifications || '',
    '',
    'LANGUAGES',
    structuredResume.Languages || structuredResume.languages || '',
    '',
    'ADDITIONAL',
    structuredResume.Additional || structuredResume.additional || structuredResume.rawText || '',
    '',
    'PDF_LAYOUT',
    structuredResume.pdfLayout ||
      'Use bold section titles and horizontal separators before each major section.',
  ];

  return Buffer.from(baseSections.join('\n'), 'utf-8');
};

const buildSignedUrl = async (s3Key) =>
  getSignedUrl(
    s3Client,
    new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: s3Key,
    }),
    { expiresIn: 60 * 15 }
  );

// Shared exports
module.exports = {
  response,
  getUserId,
  parseJson,
  extractResumeJson,
  buildResumePrompt,
  renderPseudoPdfContent,
  buildSignedUrl,
  docClient,
  s3Client,
  bedrockClient,
  TABLE_NAME,
  BUCKET_NAME,
  HAIKU_MODEL_ID,
};
