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
) => `Acting as a professional resume writer, transform this JSON data into a structured resume.
Return ONLY a valid JSON object containing optimized natural language text for each section (Header, Summary, Experience, Skills, Education, Certifications, Languages, Additional) and a "pdfLayout" field with instructions for bold titles and horizontal lines.

Use Harvard Resume style:
- Header format: Name | Location | Email | Phone | LinkedIn | GitHub.
- Section headers in uppercase bold (for example: EDUCATION, PROFESSIONAL EXPERIENCE).
- Keep language concise, achievement-oriented, and quantified where possible.

Input JSON:
${JSON.stringify(cvData, null, 2)}`;

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
