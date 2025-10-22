graph TB
    subgraph "iOS App - AI Features"
        A[ChatView with Translation] --> B[Inline Translation Button]
        A --> C[Auto-Translate Toggle]
        A --> D[Smart Reply Suggestions]
        E[AI Assistant Chat] --> F[RAG Query Interface]
        E --> G[AI Memory Viewer]
        H[Message Long Press] --> I[Formality Check]
        H --> J[Explain Slang/Idiom]
        H --> K[Cultural Context]
    end

    subgraph "iOS ViewModels"
        L[ChatViewModel]
        M[AIAssistantViewModel]
        N[TranslationViewModel]
        O[SmartReplyViewModel]
    end

    subgraph "iOS Services"
        P[AIService]
        Q[TranslationCacheService]
        R[EmbeddingService]
    end

    subgraph "Firebase Cloud Functions"
        S[translateMessage]
        T[detectLanguage]
        U[generateSmartReplies]
        V[analyzeCulturalContext]
        W[analyzeFormality]
        X[adjustFormality]
        Y[detectSlangIdioms]
        Z[explainPhrase]
        AA[semanticSearch]
        AB[extractStructuredData]
    end

    subgraph "Firestore Trigger"
        AC[generateEmbedding]
    end

    subgraph "AI Services"
        AD[OpenAI GPT-4]
        AE[OpenAI Embeddings]
        AF[Google Translate API]
    end

    subgraph "Firestore Collections"
        AG[(translations)]
        AH[(message_embeddings)]
        AI[(ai_assistant_memory)]
        AJ[(detected_phrases)]
        AK[(smart_reply_usage)]
        AL[(extracted_data)]
    end

    subgraph "RAG Pipeline"
        AM[Query Embedding]
        AN[Vector Search]
        AO[Context Retrieval]
        AP[LLM Synthesis]
    end

    subgraph "Existing Data"
        AQ[(messages)]
        AR[(conversations)]
        AS[(users)]
    end

    B --> L
    C --> L
    D --> O
    F --> M
    I --> N
    J --> N
    K --> N

    L --> P
    M --> P
    N --> P
    O --> P

    P --> S
    P --> T
    P --> U
    P --> V
    P --> W
    P --> X
    P --> Y
    P --> Z
    P --> AA
    P --> AB

    S --> AD
    T --> AD
    U --> AD
    V --> AD
    W --> AD
    X --> AD
    Y --> AD
    Z --> AD
    AB --> AD

    S --> AF
    AA --> AE

    AQ -.Trigger.-> AC
    AC --> AE
    AC --> AH

    S --> AG
    U --> AK
    Y --> AJ
    AB --> AL
    M --> AI

    AA --> AM
    AM --> AN
    AN --> AH
    AN --> AO
    AO --> AQ
    AO --> AP
    AP --> AD

    P --> Q
    Q --> AG

    style A fill:#e1f5ff
    style E fill:#e1f5ff
    style AD fill:#fff3e0
    style AE fill:#fff3e0
    style AF fill:#fff3e0
    style AG fill:#f3e5f5
    style AH fill:#f3e5f5
    style AI fill:#f3e5f5
    style AJ fill:#f3e5f5
    style AK fill:#f3e5f5
    style AL fill:#f3e5f5
    style AM fill:#ffebee
    style AN fill:#ffebee
    style AO fill:#ffebee
    style AP fill:#ffebee