const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME;

exports.saveResume = async (item) => {
    const params = {
        TableName: TABLE_NAME,
        Item: item
    };
    return await docClient.send(new PutCommand(params));
};