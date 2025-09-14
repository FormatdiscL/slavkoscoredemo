import React, { createContext, useContext, useState, useEffect } from 'react';
import { getFirestore, collection, doc, onSnapshot } from 'firebase/firestore';

// Define types for our evaluation data
interface Evaluation {
  id: string;
  agentId: string;
  metrics: {
    slavkoScore: number;
    scoreChange: number;
    autonomyLevel: number;
    codeQuality: {
      score: number;
      change: number;
    };
    performance: number;
  };
  createdAt: Date;
  updatedAt: Date;
}

interface RealTimeMetrics {
  [agentId: string]: {
    slavkoScore?: number;
    scoreChange?: number;
    autonomyLevel?: number;
    codeQuality?: {
      score?: number;
      change?: number;
    };
    performance?: number;
  };
}

interface EvaluationContextType {
  evaluations: Evaluation[];
  loading: boolean;
  error: string | null;
  realTimeMetrics: RealTimeMetrics;
  subscribeToAgent: (agentId: string) => void;
  unsubscribeFromAgent: (agentId: string) => void;
}

const EvaluationContext = createContext<EvaluationContextType | undefined>(undefined);

export const EvaluationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [evaluations, setEvaluations] = useState<Evaluation[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [realTimeMetrics, setRealTimeMetrics] = useState<RealTimeMetrics>({});
  const [subscriptions, setSubscriptions] = useState<{ [agentId: string]: () => void }>({});

  // Fetch initial evaluations
  useEffect(() => {
    const fetchEvaluations = async () => {
      try {
        setLoading(true);
        const db = getFirestore();
        
        // Subscribe to evaluations collection
        const unsubscribe = onSnapshot(
          collection(db, 'evaluations'),
          (snapshot) => {
            const evaluationsData = snapshot.docs.map(doc => ({
              id: doc.id,
              ...doc.data(),
              createdAt: doc.data().createdAt?.toDate(),
              updatedAt: doc.data().updatedAt?.toDate(),
            })) as Evaluation[];
            
            setEvaluations(evaluationsData);
            setLoading(false);
          },
          (err) => {
            console.error('Error fetching evaluations:', err);
            setError('Failed to load evaluations data');
            setLoading(false);
          }
        );
        
        // Cleanup subscription
        return () => unsubscribe();
      } catch (err) {
        console.error('Error in evaluation context setup:', err);
        setError('Failed to initialize evaluations');
        setLoading(false);
      }
    };
    
    fetchEvaluations();
  }, []);

  // Subscribe to real-time updates for a specific agent
  const subscribeToAgent = (agentId: string) => {
    // Don't create duplicate subscriptions
    if (subscriptions[agentId]) return;
    
    try {
      const db = getFirestore();
      const agentRef = doc(db, 'agents', agentId);
      
      const unsubscribe = onSnapshot(agentRef, (docSnapshot) => {
        if (docSnapshot.exists()) {
          const data = docSnapshot.data();
          
          setRealTimeMetrics(prev => ({
            ...prev,
            [agentId]: {
              slavkoScore: data.metrics?.slavkoScore,
              scoreChange: data.metrics?.scoreChange,
              autonomyLevel: data.metrics?.autonomyLevel,
              codeQuality: data.metrics?.codeQuality,
              performance: data.metrics?.performance
            }
          }));
        }
      });
      
      // Store the unsubscribe function
      setSubscriptions(prev => ({
        ...prev,
        [agentId]: unsubscribe
      }));
    } catch (err) {
      console.error(`Error subscribing to agent ${agentId}:`, err);
    }
  };

  // Unsubscribe from real-time updates for a specific agent
  const unsubscribeFromAgent = (agentId: string) => {
    if (subscriptions[agentId]) {
      subscriptions[agentId]();
      setSubscriptions(prev => {
        const newSubscriptions = { ...prev };
        delete newSubscriptions[agentId];
        return newSubscriptions;
      });
    }
  };

  // Cleanup subscriptions on unmount
  useEffect(() => {
    return () => {
      Object.values(subscriptions).forEach(unsubscribe => unsubscribe());
    };
  }, [subscriptions]);

  return (
    <EvaluationContext.Provider
      value={{
        evaluations,
        loading,
        error,
        realTimeMetrics,
        subscribeToAgent,
        unsubscribeFromAgent
      }}
    >
      {children}
    </EvaluationContext.Provider>
  );
};

export const useEvaluationContext = () => {
  const context = useContext(EvaluationContext);
  if (context === undefined) {
    throw new Error('useEvaluationContext must be used within an EvaluationProvider');
  }
  return context;
};