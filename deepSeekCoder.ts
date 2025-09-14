import * as functions from 'firebase-functions';
import { getFirestore } from '../utils/firebaseAdmin';
import axios from 'axios';
import * as admin from 'firebase-admin';

// Define the interface for code quality analysis results
interface CodeQualityAnalysis {
  score: number;
  bugDensity: number;
  optimizationLevel: number;
  maintainability: number;
  securityIssues: number;
  efficiency: number;
}

const DEEPSEEK_API_URL = 'https://api.deepseek.com/v1/coder/analyze';
const MAX_CODE_LENGTH = 10000; // ~10KB limit

// Internal handler for use within other functions
export const analyzeCodeQualityHandler = async (
  code: string, 
  language: string = 'python'
): Promise<CodeQualityAnalysis> => {
  if (!code || typeof code !== 'string') {
    throw new Error('Code parameter is required and must be a string');
  }

  if (code.length > MAX_CODE_LENGTH) {
    throw new Error(`Code exceeds maximum length of ${MAX_CODE_LENGTH} characters`);
  }

  try {
    const response = await axios.post(
      DEEPSEEK_API_URL,
      { code, language },
      {
        headers: {
          'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    return {
      score: response.data.score,
      bugDensity: response.data.bug_density,
      optimizationLevel: response.data.optimization_level,
      maintainability: response.data.maintainability_index,
      securityIssues: response.data.security_issues,
      efficiency: response.data.efficiency_score
    };
  } catch (error: any) {
    console.error('DeepSeek API error:', error);
    throw new Error(error.response?.data?.error || 'Failed to analyze code quality');
  }
};

// Cloud Function wrapper
export const analyzeCodeQuality = functions.runWith({
  timeoutSeconds: 60,
  memory: '1GB'
}).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { code, language = 'python' } = data;
  
  try {
    const analysis = await analyzeCodeQualityHandler(code, language);
    
    // Cache results in Firestore for 1 hour
    const db = getFirestore();
    const cacheRef = db.collection('codeAnalysisCache').doc();
    
    await cacheRef.set({
      ...analysis,
      codeSnippet: code.substring(0, 500),
      userId: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 3600000)
    });

    return analysis;
  } catch (error: any) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});