# Technical Corrections & Best Practices

## Issues Found in Current Implementation

### 1. CORS Configuration — Security Issue 🔴

**Location**: `/backend/serverless.yaml` lines 36-40

**Current**:
```yaml
httpApi:
  cors:
    allowedOrigins:
      - '*'
```

**Problem**: Allows requests from ANY origin, including malicious websites.

**Fix in Terraform**:
```hcl
resource "aws_apigatewayv2_api" "http_api" {
  name          = "hojadevida-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins     = ["https://cv.example.com", "https://localhost:3000"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["Content-Type", "Authorization"]
    expose_headers    = ["Content-Length"]
    max_age          = 300
    allow_credentials = true  # Only if using credentials
  }
}
```

**For Development**: Use regex pattern
```hcl
allow_origins = ["https://*.example.com", "http://localhost:3000"]
```

---

### 2. API Response Headers Missing 🟡

**Location**: `/backend/handler.js` lines 18-24

**Current**:
```javascript
const response = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(body),
});
```

**Problem**: Missing security headers that should be on every response.

**Fix**:
```javascript
const response = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'X-Content-Type-Options': 'nosniff',           // Prevent MIME sniffing
    'X-Frame-Options': 'DENY',                     // Block clickjacking
    'X-XSS-Protection': '1; mode=block',           // Browser XSS filter
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',  // HTTPS only
    'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',  // No caching
  },
  body: JSON.stringify(body),
});
```

**Alternative**: Add as middleware or API Gateway policy (cleaner in Terraform).

---

### 3. Error Messages Leak Internal Details 🟡

**Location**: `/backend/handler.js` multiple locations

**Current**:
```javascript
catch (error) {
  console.error('generateCv error', error);
  return response(500, { message: 'Failed to generate CV.' });
}
```

**Problem**: Generic message is good, but internal logging should not expose implementation details to console.

**Better**:
```javascript
catch (error) {
  const errorId = randomUUID();  // Trace ID for support
  
  // Log full error internally (won't be exposed to client)
  console.error(`[${errorId}] generateCv failed:`, {
    message: error.message,
    stack: error.stack,
    userId,  // For debugging
    bedrockError: error.Code,  // If Bedrock error
  });
  
  // Return generic message with trace ID
  return response(500, { 
    message: 'Failed to generate CV. Please try again later.',
    errorId,  // Client includes in support request
  });
}
```

**In Production**: Send error logs to CloudWatch Logs with structured format.

---

### 4. DynamoDB Query Missing Projections 🟡

**Location**: `/backend/handler.js` lines 129-141 (listCvs function)

**Current**:
```javascript
const queryResult = await docClient.send(
  new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: '#userId = :userId',
    ExpressionAttributeNames: { '#userId': 'userId' },
    ExpressionAttributeValues: { ':userId': userId },
    ScanIndexForward: false,
  })
);
```

**Problem**: Returns ALL attributes. If you add large fields later (e.g., `description`, `metadata`), this becomes slow and expensive.

**Fix - Add Projection**:
```javascript
const queryResult = await docClient.send(
  new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: '#userId = :userId',
    ExpressionAttributeNames: { '#userId': 'userId' },
    ExpressionAttributeValues: { ':userId': userId },
    ProjectionExpression: 'userId, cvId, #name, createdAt, s3Key',  // Only fetch these
    ExpressionAttributeNames: {
      '#userId': 'userId',
      '#name': 'name',
    },
    ScanIndexForward: false,
  })
);
```

---

### 5. S3 Presigned URL Expiration Too Short? 🟡

**Location**: `/backend/handler.js` line 118

**Current**:
```javascript
const buildSignedUrl = async (s3Key) =>
  getSignedUrl(
    s3Client,
    new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: s3Key,
    }),
    { expiresIn: 60 * 15 }  // 15 minutes
  );
```

**Consideration**: 15 minutes may be too short for slow downloads or sharing with others.

**Recommendation for Phase 2**:
- List API: Use longer expiration (4 hours) since user is already authenticated
- Download: Use shorter expiration (1 hour) for security
- Share with others: Use Cognito-based access control or create signed share links

```javascript
const buildSignedUrl = async (s3Key, expiresIn = 3600) =>  // Default 1 hour
  getSignedUrl(
    s3Client,
    new GetObjectCommand({ Bucket: BUCKET_NAME, Key: s3Key }),
    { expiresIn }
  );
```

---

### 6. Bedrock Token Usage Not Monitored 🟡

**Location**: `/backend/handler.js` lines 180-198 (generateCv function)

**Current**:
```javascript
const bedrockResult = await bedrockClient.send(
  new InvokeModelCommand({
    modelId: HAIKU_MODEL_ID,
    body: JSON.stringify({
      anthropic_version: 'bedrock-2023-05-31',
      max_tokens: 1800,
      temperature: 0.3,
      messages: [/* ... */],
    }),
  })
);
```

**Problem**: No way to track token usage or cost. Could silently waste tokens if Bedrock behavior changes.

**Fix - Track Usage**:
```javascript
const bedrockResult = await bedrockClient.send(/* ... */);
const bedrockPayload = JSON.parse(new TextDecoder().decode(bedrockResult.body));

// Log token usage for cost tracking
console.log('Bedrock token usage:', {
  jobId: cvId,
  userId,
  inputTokens: bedrockPayload.usage?.input_tokens,
  outputTokens: bedrockPayload.usage?.output_tokens,
  totalTokens: (bedrockPayload.usage?.input_tokens || 0) + (bedrockPayload.usage?.output_tokens || 0),
  estimatedCost: ((bedrockPayload.usage?.input_tokens || 0) * 0.00025 + 
                   (bedrockPayload.usage?.output_tokens || 0) * 0.00125) / 1000,
});
```

**Phase 2 Enhancement**: Store token metrics in DynamoDB for billing analysis.

---

### 7. No Retry Logic for Transient Failures 🟡

**Location**: `/backend/handler.js` generateCv function

**Current**: Single attempt, if Bedrock fails, returns 500 error immediately.

**Fix - Exponential Backoff**:
```javascript
const invokeBedrockWithRetry = async (payload, maxRetries = 3) => {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await bedrockClient.send(
        new InvokeModelCommand(payload)
      );
    } catch (error) {
      if (attempt === maxRetries || !isRetryableError(error)) {
        throw error;
      }
      
      const delayMs = Math.pow(2, attempt) * 1000;  // Exponential: 2s, 4s, 8s
      console.log(`Bedrock attempt ${attempt} failed, retrying in ${delayMs}ms`, error.message);
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
};

const isRetryableError = (error) => {
  return (
    error.name === 'ThrottlingException' ||
    error.name === 'ServiceUnavailableException' ||
    error.name === 'RequestTimeoutException'
  );
};
```

---

### 8. Frontend Authentication Not Persisted on Reload 🟡

**Location**: `/frontend/app/create-cv/page.tsx` lines 17-38

**Current**:
```javascript
useEffect(() => {
  let mounted = true;

  isAuthenticated()
    .then((result) => {
      if (!mounted) return;
      setAuthed(result);
      setChecking(false);
    })
    .catch(() => {
      if (!mounted) return;
      setAuthed(false);
      setChecking(false);
    });

  return () => { mounted = false; };
}, []);
```

**Problem**: Checks authentication on EVERY page load, even if user just authenticated. Better to cache token state.

**Fix - Cache with useCallback + localStorage fallback**:
```javascript
import { useCallback, useEffect, useState } from 'react';

const useAuthState = () => {
  const [authed, setAuthed] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    let mounted = true;

    // Try to get cached token first
    const checkAuth = async () => {
      try {
        const { accessToken } = await Auth.currentSession();
        if (mounted && accessToken) {
          setAuthed(true);
        }
      } catch (error) {
        if (mounted) {
          setAuthed(false);
        }
      } finally {
        if (mounted) setChecking(false);
      }
    };

    checkAuth();
    return () => { mounted = false; };
  }, []);

  return { authed, checking };
};
```

---

### 9. Form Wizard State Lost on Page Refresh 🟡

**Location**: `/frontend/components/FormWizard.tsx`

**Current**: Form state only in React state (memory).

**Problem**: User fills out form, page refreshes, loses all data.

**Fix - Auto-save to localStorage**:
```javascript
const [formData, setFormData] = useState(initialState);

// Save to localStorage on every change
useEffect(() => {
  localStorage.setItem('cv_form_draft', JSON.stringify(formData));
}, [formData]);

// Load from localStorage on mount
useEffect(() => {
  const saved = localStorage.getItem('cv_form_draft');
  if (saved) {
    try {
      setFormData(JSON.parse(saved));
    } catch (e) {
      console.warn('Failed to restore form draft');
    }
  }
}, []);

// Clear draft after successful submission
const handleSubmit = async () => {
  // ... submit logic
  localStorage.removeItem('cv_form_draft');
};
```

---

### 10. No TypeScript Strict Mode 🟡

**Location**: `/frontend/tsconfig.json`

**Current**: Unknown (not provided)

**Recommendation**: Enable strict mode
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

This prevents many runtime errors at compile time.

---

## Best Practices to Adopt

### 1. Environment Variable Validation

**File**: `backend/lib/env-validator.ts`

```typescript
const requiredEnv = [
  'CVS_TABLE',
  'CVS_BUCKET',
  'BEDROCK_MODEL_ID',
] as const;

export const validateEnv = () => {
  for (const env of requiredEnv) {
    if (!process.env[env]) {
      throw new Error(`Missing required environment variable: ${env}`);
    }
  }
};

// Call in handler before processing
validateEnv();
```

### 2. Structured Logging

**File**: `backend/lib/logger.ts`

```typescript
export const logger = {
  info: (message: string, context = {}) => {
    console.log(JSON.stringify({ level: 'INFO', message, ...context }));
  },
  error: (message: string, error: Error, context = {}) => {
    console.error(JSON.stringify({ 
      level: 'ERROR', 
      message, 
      error: error.message,
      stack: error.stack,
      ...context 
    }));
  },
};

// Usage in handlers
logger.error('CV generation failed', error, { cvId, userId });
```

CloudWatch will parse these JSON logs automatically.

### 3. Request ID Tracing

**File**: `backend/lib/request-context.ts`

```typescript
export const extractRequestContext = (event: any) => ({
  requestId: event.requestContext.requestId,
  userId: event.requestContext.authorizer.jwt.claims.sub,
  timestamp: new Date().toISOString(),
  path: event.requestContext.http.path,
  method: event.requestContext.http.method,
});

// Usage in handlers
const ctx = extractRequestContext(event);
logger.info('Starting CV generation', ctx);
```

All logs include request ID for tracing through system.

### 4. API Response Envelope

**File**: `backend/lib/response.ts`

```typescript
export const successResponse = (statusCode: number, data: any) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  },
  body: JSON.stringify({
    success: true,
    data,
    timestamp: new Date().toISOString(),
  }),
});

export const errorResponse = (statusCode: number, message: string, errorId: string) => ({
  statusCode,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    success: false,
    error: { message, id: errorId },
    timestamp: new Date().toISOString(),
  }),
});
```

Consistent response format makes client integration easier.

---

## Summary: Quick Fixes Before Phase 1

- [ ] Add security headers to API responses
- [ ] Implement CORS restrictions (prepare variable for frontend domain)
- [ ] Add error trace IDs
- [ ] Add DynamoDB projection expressions
- [ ] Document S3 presigned URL expiration strategy
- [ ] Add Bedrock token usage logging
- [ ] Implement Bedrock retry logic
- [ ] Review frontend auth caching strategy
- [ ] Add localStorage persistence for form drafts
- [ ] Enable TypeScript strict mode

**None of these are blockers for Phase 1**, but should be integrated during Phase 2 (backend improvements).

---

**Ready to proceed with Phase 1 Terraform refactor with these best practices in mind?**
