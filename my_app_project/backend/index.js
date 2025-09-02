
const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const axios = require('axios');
const multer = require('multer');
const speech = require('@google-cloud/speech');
const textToSpeech = require('@google-cloud/text-to-speech');

// Load environment variables
dotenv.config();
const app = express();
const port = process.env.PORT || 3000;

// Enable CORS for all routes
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10mb' }));

// Initialize Firebase
let db;
let firebaseInitialized = false;
async function initializeFirebase() {
  if (firebaseInitialized) return true;
  try {
    let serviceAccount;
    // Check if using a service account file
    if (process.env.FIREBASE_SERVICE_ACCOUNT_FILE) {
      const serviceAccountPath = path.join(__dirname, process.env.FIREBASE_SERVICE_ACCOUNT_FILE);
      console.log('Loading service account from:', serviceAccountPath);
      // Check if file exists
      if (!require('fs').existsSync(serviceAccountPath)) {
        throw new Error(`Service account file not found at: ${serviceAccountPath}`);
      }
      serviceAccount = require(serviceAccountPath);
    }
    // Otherwise check if the service account is provided as a JSON string
    else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      console.log('Loading service account from environment variable');
      try {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      } catch (parseError) {
        throw new Error(`Failed to parse FIREBASE_SERVICE_ACCOUNT JSON: ${parseError.message}`);
      }
    } else {
      throw new Error('Firebase service account not provided. Set FIREBASE_SERVICE_ACCOUNT_FILE or FIREBASE_SERVICE_ACCOUNT');
    }
    // Validate required service account fields
    const requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id'];
    for (const field of requiredFields) {
      if (!serviceAccount[field]) {
        throw new Error(`Service account missing required field: ${field}`);
      }
    }
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    db = admin.firestore();
    firebaseInitialized = true;
    console.log('Firebase initialized successfully');
    return true;
  } catch (error) {
    console.error('Failed to initialize Firebase:', error.message);
    firebaseInitialized = false;
    return false;
  }
}

// Initialize Google Cloud services
let speechClient;
let ttsClient;
try {
  speechClient = new speech.SpeechClient();
  ttsClient = new textToSpeech.TextToSpeechClient();
  console.log('Google Cloud services initialized');
} catch (error) {
  console.error('Failed to initialize Google Cloud services:', error.message);
}

// Configure multer for file uploads
const upload = multer({ dest: 'uploads/' });

// Rasa configuration
const RASA_URL = process.env.RASA_URL || 'http://localhost:5005';

// Form submission endpoint
app.post('/submit-form', async (req, res) => {
  if (!firebaseInitialized) {
    const initialized = await initializeFirebase();
    if (!initialized) {
      return res.status(500).json({
        success: false,
        error: 'Firebase not initialized'
      });
    }
  }
  try {
    console.log('Received form data:', req.body);
    // Validate required fields
    const { username, email, password } = req.body;
    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: username, email, password'
      });
    }
    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid email format'
      });
    }
    // Prepare form data with additional metadata
    const formData = {
      ...req.body,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: req.ip,
      userAgent: req.get('User-Agent')
    };
    // Save to Firestore
    const docRef = await db.collection('form_submissions').add(formData);
    console.log('Form submitted with ID:', docRef.id);
    res.status(200).json({
      success: true,
      id: docRef.id,
      message: 'Form submitted successfully'
    });
  } catch (error) {
    console.error('Error submitting form:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get all form submissions with pagination
app.get('/form-submissions', async (req, res) => {
  if (!firebaseInitialized) {
    const initialized = await initializeFirebase();
    if (!initialized) {
      return res.status(500).json({
        success: false,
        error: 'Firebase not initialized'
      });
    }
  }
  try {
    // Parse pagination parameters
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;
    // Get total count for pagination metadata
    const snapshotCount = await db.collection('form_submissions').count().get();
    const totalCount = snapshotCount.data().count;
    // Get paginated submissions
    const snapshot = await db.collection('form_submissions')
      .orderBy('submittedAt', 'desc')
      .offset(offset)
      .limit(limit)
      .get();
    const submissions = [];
    snapshot.forEach(doc => {
      submissions.push({
        id: doc.id,
        ...doc.data()
      });
    });
    res.status(200).json({
      success: true,
      submissions: submissions,
      pagination: {
        totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit),
        limit
      }
    });
  } catch (error) {
    console.error('Error fetching form submissions:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Chatbot endpoint - text-based
app.post('/api/chatbot', async (req, res) => {
  try {
    const { message, language = 'en', sender } = req.body;

    if (!message) {
      return res.status(400).json({
        success: false,
        error: 'Message is required'
      });
    }

    console.log(`Received chat message in ${language}: ${message}`);

    // Send message to Rasa
    const rasaResponse = await axios.post(`${RASA_URL}/webhooks/rest/webhook`, {
      sender: sender || 'default',
      message: message
    });

    // Extract responses from Rasa
    const responses = rasaResponse.data;

    // If we want to convert text to speech
    let audioResponse = null;
    if (req.body.includeAudio && ttsClient) {
      try {
        const text = responses.map(r => r.text).join(' ');
        const request = {
          input: { text: text },
          voice: { languageCode: getLanguageCode(language) },
          audioConfig: { audioEncoding: 'MP3' },
        };

        const [response] = await ttsClient.synthesizeSpeech(request);
        audioResponse = response.audioContent.toString('base64');
      } catch (ttsError) {
        console.error('Text-to-speech conversion failed:', ttsError.message);
      }
    }

    res.status(200).json({
      success: true,
      responses: responses,
      audio: audioResponse
    });
  } catch (error) {
    console.error('Error in chatbot endpoint:', error.message);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Voice chat endpoint - processes audio input
app.post('/api/voice-chat', upload.single('audio'), async (req, res) => {
  try {
    const { language = 'en' } = req.body;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'Audio file is required'
      });
    }

    console.log(`Received voice message in ${language}`);

    // Convert speech to text if speech client is available
    let text = '';
    if (speechClient) {
      try {
        const audio = {
          content: require('fs').readFileSync(req.file.path).toString('base64'),
        };

        const config = {
          encoding: 'LINEAR16',
          sampleRateHertz: 16000,
          languageCode: getLanguageCode(language),
        };

        const request = {
          audio: audio,
          config: config,
        };

        const [response] = await speechClient.recognize(request);
        const transcription = response.results
          .map(result => result.alternatives[0].transcript)
          .join('\n');

        text = transcription;
        console.log(`Transcribed text: ${text}`);

        // Clean up the uploaded file
        require('fs').unlinkSync(req.file.path);
      } catch (sttError) {
        console.error('Speech-to-text conversion failed:', sttError.message);
        // Clean up the uploaded file
        require('fs').unlinkSync(req.file.path);
        return res.status(500).json({
          success: false,
          error: 'Speech-to-text conversion failed'
        });
      }
    } else {
      // Clean up the uploaded file
      require('fs').unlinkSync(req.file.path);
      return res.status(500).json({
        success: false,
        error: 'Speech-to-text service not available'
      });
    }

    // Send transcribed text to Rasa
    const rasaResponse = await axios.post(`${RASA_URL}/webhooks/rest/webhook`, {
      sender: 'voice-user',
      message: text
    });

    // Extract responses from Rasa
    const responses = rasaResponse.data;

    // Convert response to speech
    let audioResponse = null;
    if (ttsClient) {
      try {
        const responseText = responses.map(r => r.text).join(' ');
        const request = {
          input: { text: responseText },
          voice: { languageCode: getLanguageCode(language) },
          audioConfig: { audioEncoding: 'MP3' },
        };

        const [response] = await ttsClient.synthesizeSpeech(request);
        audioResponse = response.audioContent.toString('base64');
      } catch (ttsError) {
        console.error('Text-to-speech conversion failed:', ttsError.message);
      }
    }

    res.status(200).json({
      success: true,
      transcribedText: text,
      responses: responses,
      audio: audioResponse
    });
  } catch (error) {
    console.error('Error in voice chat endpoint:', error.message);
    if (req.file && require('fs').existsSync(req.file.path)) {
      require('fs').unlinkSync(req.file.path);
    }
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Helper function to get language code for Google Cloud services
function getLanguageCode(language) {
  switch (language.toLowerCase()) {
    case 'tamil':
    case 'ta':
      return 'ta-IN';
    case 'hindi':
    case 'hi':
      return 'hi-IN';
    case 'tanglish':
    case 'en':
    default:
      return 'en-US';
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    firebase: firebaseInitialized ? 'Initialized' : 'Not initialized',
    rasa: RASA_URL ? 'Configured' : 'Not configured'
  });
});

// Start server
initializeFirebase().then(() => {
  app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
  });
}).catch((error) => {
  console.error('Failed to start server:', error.message);
  process.exit(1);
});
