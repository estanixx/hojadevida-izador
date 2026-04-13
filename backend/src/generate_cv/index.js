const { randomUUID } = require('node:crypto');
const { PutCommand } = require('@aws-sdk/lib-dynamodb');
const { InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const {
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
} = require('../shared');
const { PutObjectCommand } = require('@aws-sdk/client-s3');

exports.handler = async (event) => {
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
