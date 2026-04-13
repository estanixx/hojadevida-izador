const { QueryCommand } = require('@aws-sdk/lib-dynamodb');
const {
  response,
  getUserId,
  docClient,
  buildSignedUrl,
  TABLE_NAME,
} = require('../shared');

exports.handler = async (event) => {
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
