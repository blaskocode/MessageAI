# Cloud Functions Setup Guide

## Prerequisites
- Node.js 20 (required for Firebase Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- OpenAI API Key

## Installation

1. Install dependencies:
```bash
cd functions
npm install
```

2. Build TypeScript:
```bash
npm run build
```

## Environment Configuration

### Option 1: Firebase Config (Production)

Set environment variables in Firebase:

```bash
# Set OpenAI API Key
firebase functions:config:set openai.key="your-openai-api-key-here"

# Set OpenAI Model (optional, defaults to gpt-4-turbo-preview)
firebase functions:config:set openai.model="gpt-4-turbo-preview"

# Set Embedding Model (optional, defaults to text-embedding-ada-002)
firebase functions:config:set openai.embedding_model="text-embedding-ada-002"
```

View current config:
```bash
firebase functions:config:get
```

### Option 2: Environment Variables (Local Development)

Create a `.env` file in the `functions` directory:

```bash
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4-turbo-preview
EMBEDDING_MODEL=text-embedding-ada-002
```

**Note:** The `.env` file is ignored by git for security.

## Local Testing

1. Start Firebase emulators:
```bash
npm run serve
```

2. Run the functions shell:
```bash
npm run shell
```

## Deployment

Deploy all functions:
```bash
npm run deploy
```

Deploy specific function:
```bash
firebase deploy --only functions:translateMessage
```

## Function Structure

```
functions/
├── src/
│   ├── helpers/          # Shared utilities
│   │   ├── llm.ts        # OpenAI client & utilities
│   │   ├── cache.ts      # Firestore caching
│   │   ├── validation.ts # Input validation
│   │   └── types.ts      # TypeScript interfaces
│   ├── ai/              # AI feature functions (added in subsequent PRs)
│   └── index.ts         # Function exports
├── package.json
├── tsconfig.json
└── SETUP.md (this file)
```

## Testing

Run unit tests:
```bash
npm test
```

Watch mode for development:
```bash
npm run test:watch
```

## Cost Management

To minimize OpenAI API costs:
- All translations are cached in Firestore
- Embeddings are generated once and reused
- Smart replies use cached conversation context
- Failed requests use exponential backoff

Monitor usage in:
- Firebase Console → Functions → Logs
- OpenAI Dashboard → Usage

## Troubleshooting

### "OpenAI API key not configured"
- Ensure `openai.key` is set in Firebase config
- Or set `OPENAI_API_KEY` environment variable locally

### Build errors
```bash
# Clean build
rm -rf lib/
npm run build
```

### Deployment fails
```bash
# Check Firebase project
firebase use

# View deployment logs
firebase functions:log
```

## Security Best Practices

1. **Never commit API keys** - Use Firebase config or `.env` (ignored by git)
2. **Validate all inputs** - All functions use validation helpers
3. **Authenticate users** - Functions require authentication where appropriate
4. **Rate limiting** - Consider implementing per-user rate limits for production
5. **Monitor costs** - Set up billing alerts in OpenAI and Firebase dashboards

## Phase 2 AI Features

Functions will be added progressively:

- **PR #2:** Translation & Language Detection
- **PR #3:** Cultural Context Analysis
- **PR #4:** Formality Detection/Adjustment
- **PR #5:** Slang & Idiom Explanations
- **PR #6:** Message Embeddings & Semantic Search
- **PR #7:** Smart Replies with Style Learning
- **PR #8:** AI Assistant with RAG
- **PR #9:** Structured Data Extraction

Each PR will add new functions while maintaining backward compatibility with existing features.

