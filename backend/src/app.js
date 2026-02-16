// backend/src/app.js
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

// Initialize Client (Logic checks if we are in LocalStack or Prod)
// In Lambda, environment variables like AWS_ENDPOINT_URL are auto-set by the runtime if configured
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.lambdaHandler = async (event, context) => {
    console.log("Event Received:", JSON.stringify(event));
    
    // 1. Parse Body
    let body;
    try {
        body = JSON.parse(event.body);
    } catch (err) {
        body = event.body;
    }

    const userId = body.userId || "unknown-user";
    const resumeData = body.data || "No data";

    // 2. Save to DynamoDB (Tier 3 connection)
    const params = {
        TableName: process.env.TABLE_NAME,
        Item: {
            userId: userId,
            content: resumeData,
            createdAt: new Date().toISOString()
        }
    };

    try {
        await docClient.send(new PutCommand(params));
        
        return {
            statusCode: 200,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ 
                message: "Resume Saved!", 
                id: userId,
                environment: "Production-Ready Tier 2"
            }),
        };
    } catch (err) {
        console.error(err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Failed to save data", details: err.message }),
        };
    }
};