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

exports.listCvs = async (event) => {
  const userId = getUserId(event);

  if (!userId) {
    return response(401, { message: 'Unauthorized' });
  }

  try {
    const queryResult = await docClient.send(
      new QueryCommand({
        TableName: TABLE_NAME,
        KeyConditionExpression: '#userId = :userId',
        ExpressionAttributeNames: {
          '#userId': 'userId',
        },
        ExpressionAttributeValues: {
          ':userId': userId,
        },
        ScanIndexForward: false,
      })
    );

    const items = queryResult.Items || [];
    const enrichedItems = await Promise.all(
      items.map(async (item) => {
        const downloadUrl = item.s3Key ? await buildSignedUrl(item.s3Key) : item.s3Link;
        return {
          ...item,
          downloadUrl,
        };
      })
    );

    return response(200, { items: enrichedItems });
  } catch (error) {
    console.error('listCvs error', error);
    return response(500, { message: 'Failed to list CVs.' });
  }
};

exports.generateCv = async (event) => {
  const userId = getUserId(event);

  if (!userId) {
    return response(401, { message: 'Unauthorized' });
  }

  const parsedBody = parseJson(event.body);
  const cvData = parsedBody?.cvData || parsedBody;

  if (!cvData || typeof cvData !== 'object') {
    return response(400, { message: 'Invalid payload. CV data is required.' });
  }

  const cvId = randomUUID();
  const fullName = cvData?.personalInfo?.fullName || 'Untitled CV';
  const objectKey = `${userId}/${cvId}.pdf`;

  try {
    const prompt = buildResumePrompt(cvData);
    const bedrockResult = await bedrockClient.send(
      new InvokeModelCommand({
        modelId: HAIKU_MODEL_ID,
        contentType: 'application/json',
        accept: 'application/json',
        body: JSON.stringify({
          anthropic_version: 'bedrock-2023-05-31',
          max_tokens: 1800,
          temperature: 0.3,
          messages: [
            {
              role: 'user',
              content: [{ type: 'text', text: prompt }],
            },
          ],
        }),
      })
    );

    const bedrockPayload = JSON.parse(new TextDecoder('utf-8').decode(bedrockResult.body));
    const modelText = bedrockPayload?.content?.[0]?.text || '{}';
    const structuredResume = extractResumeJson(modelText);

    const pdfBytes = renderPseudoPdfContent(fullName, structuredResume);
    await s3Client.send(
      new PutObjectCommand({
        Bucket: BUCKET_NAME,
        Key: objectKey,
        Body: pdfBytes,
        ContentType: 'application/pdf',
      })
    );

    const s3Link = `s3://${BUCKET_NAME}/${objectKey}`;
    const createdAt = new Date().toISOString();

    const item = {
      userId,
      cvId,
      name: fullName,
      s3Link,
      s3Key: objectKey,
      createdAt,
    };

    await docClient.send(
      new PutCommand({
        TableName: TABLE_NAME,
        Item: item,
      })
    );

    const downloadUrl = await buildSignedUrl(objectKey);

    return response(201, {
      message: 'CV generated successfully.',
      item: {
        ...item,
        downloadUrl,
      },
      generatedSections: structuredResume,
    });
  } catch (error) {
    console.error('generateCv error', error);
    return response(500, { message: 'Failed to generate CV.' });
  }
};

exports.hello = async () => response(200, { message: 'HOLA AL MUNDO' });
