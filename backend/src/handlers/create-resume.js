const dbAdapter = require('../adapters/dynamo-adapter');

exports.lambdaHandler = async (event, context) => {
  // FIX: Use Optional Chaining (?.) to safely access nested properties
  // If requestContext doesn't exist, use 'unknown-id' instead of crashing
  const requestId = event.requestContext?.requestId || context.awsRequestId || 'test-event';
  console.log('Processing Event:', requestId);

  let body;
  try {
    // Handle cases where body is already an object (Direct Invoke) vs string (API Gateway)
    body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch (err) {
    body = event.body || {}; // Fallback to empty object
  }

  const userId = body.userId;
  const resumeData = body.data;

  // Prepare the data model
  const newItem = {
    userId: userId,
    content: resumeData,
    createdAt: new Date().toISOString(),
  };

  try {
    // Call the separate adapter function
    await dbAdapter.saveResume(newItem);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Saved!', id: userId }),
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    };
  }
};
