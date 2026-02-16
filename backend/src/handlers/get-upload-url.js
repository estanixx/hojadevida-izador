const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

// Initialize S3 Client
// Note: In LocalStack, we need "forcePathStyle: true"
const s3 = new S3Client({
  forcePathStyle: true,
  endpoint: process.env.AWS_ENDPOINT_URL, // This will be injected by SAM/Docker
});

exports.lambdaHandler = async (event) => {
  const bucketName = process.env.BUCKET_NAME;
  // We'll use a query parameter or body to get the filename
  const fileName = event.queryStringParameters?.filename || `resume-${Date.now()}.pdf`;
  const userId = 'student-123'; // TODO: Get from Auth later

  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: `${userId}/${fileName}`, // Organize files by User ID
    ContentType: 'application/pdf',
  });

  try {
    const signedUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

    // REMOVED: const browserCompatibleUrl = signedUrl.replace("localstack", "localhost");
    // We return the raw URL. The Frontend Server Action will fix it if needed.

    return {
      statusCode: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ uploadUrl: signedUrl, filename: fileName }),
    };
  } catch (err) {
    console.error(err);
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
};
