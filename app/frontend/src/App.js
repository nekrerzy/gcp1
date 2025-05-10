import React, { useState, useEffect } from 'react';
import { Container, Paper, Typography, Grid, CircularProgress, Box, AppBar, Toolbar, Button, TextField, IconButton, Snackbar } from '@mui/material';
import HealthIcon from '@mui/icons-material/Favorite';
import ErrorIcon from '@mui/icons-material/Error';
import WarningIcon from '@mui/icons-material/Warning';
import VisibilityIcon from '@mui/icons-material/Visibility';
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import CloudIcon from '@mui/icons-material/Cloud';

// Use REACT_APP prefix as required by Create React App
const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || 'http://34.13.78.32';
console.log('Backend URL:', BACKEND_URL);

function JsonDisplay({ data }) {
  const [isExpanded, setIsExpanded] = useState(false);

  const toggleExpand = () => setIsExpanded(!isExpanded);

  return (
    <Box sx={{
      backgroundColor: '#f5f5f5',
      p: 1,
      borderRadius: 1,
      fontFamily: 'monospace',
      fontSize: '0.875rem',
      position: 'relative'
    }}>
      <IconButton
        size="small"
        onClick={toggleExpand}
        sx={{ position: 'absolute', right: 4, top: 4 }}
      >
        {isExpanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
      </IconButton>
      <pre style={{
        margin: 0,
        whiteSpace: isExpanded ? 'pre-wrap' : 'pre',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        maxHeight: isExpanded ? 'none' : '100px'
      }}>
        {JSON.stringify(data, null, 2)}
      </pre>
    </Box>
  );
}

function ServiceHealth({ name, health }) {
  const getStatusInfo = (status) => {
    switch (status?.toLowerCase()) {
      case 'healthy':
        return { color: '#4caf50', icon: <HealthIcon sx={{ color: '#4caf50' }} /> };
      case 'unhealthy':
        return { color: '#f44336', icon: <ErrorIcon sx={{ color: '#f44336' }} /> };
      default:
        return { color: '#ffc107', icon: <WarningIcon sx={{ color: '#ffc107' }} /> };
    }
  };

  // If health is null, show as unknown status
  const statusInfo = health ? getStatusInfo(health.status) : getStatusInfo('unknown');

  return (
    <Paper elevation={3} sx={{ p: 2, height: '100%', transition: 'transform 0.2s', '&:hover': { transform: 'scale(1.02)' } }}>
      <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        {statusInfo.icon} {name}
      </Typography>
      <Box sx={{ mt: 2 }}>
        <Typography variant="body1" sx={{ color: statusInfo.color, fontWeight: 'bold' }}>
          {health?.status || 'Unknown'}
        </Typography>
        {health?.latency_ms && (
          <Typography variant="body2" color="text.secondary">
            Latency: {Math.round(health.latency_ms)}ms
          </Typography>
        )}
        {health?.error && (
          <Typography variant="body2" color="error" sx={{ mt: 1, wordBreak: 'break-word' }}>
            Error: {health.error}
          </Typography>
        )}
        {health?.details && (
          <Box sx={{ mt: 1 }}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
              Details:
            </Typography>
            <JsonDisplay data={health.details} />
          </Box>
        )}
      </Box>
    </Paper>
  );
}

function WelcomeHeader() {
  return (
    <Box sx={{ textAlign: 'center', mb: 6, mt: 4 }}>
      <Typography variant="h2" component="h1" gutterBottom sx={{ fontWeight: 'bold', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <CloudIcon sx={{ fontSize: 40, mr: 2 }} /> AIS GCP GenAI Platform
      </Typography>
      <Typography variant="h5" color="text.secondary" sx={{ mb: 3 }}>
        Your Secure and Scalable AI Infrastructure for GenAI Application Development.
      </Typography>
    </Box>
  );
}

function ApiKeyInput({ apiKey, setApiKey, disabled }) {
  const [showApiKey, setShowApiKey] = useState(false);
  const [localApiKey, setLocalApiKey] = useState(apiKey);

  useEffect(() => {
    setLocalApiKey(apiKey);
  }, [apiKey]);

  const handleChange = (event) => {
    const newValue = event.target.value;
    setLocalApiKey(newValue);
    setApiKey(newValue);
  };

  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%', maxWidth: 400 }}>
      <TextField
        type={showApiKey ? 'text' : 'password'}
        label="API Key"
        variant="outlined"
        value={localApiKey}
        onChange={handleChange}
        disabled={disabled}
        fullWidth
        size="small"
        placeholder="Enter your API key"
      />
      <IconButton
        onClick={() => setShowApiKey(!showApiKey)}
        edge="end"
        disabled={disabled}
      >
        {showApiKey ? <VisibilityOffIcon /> : <VisibilityIcon />}
      </IconButton>
    </Box>
  );
}

function App() {
  const [healthData, setHealthData] = useState({
    vertex_ai_gemini: null,
    vertex_ai_index: null,
    document_ai: null,
    cloud_storage: null,
    cloud_sql: null,
    firestore: null,
    secret_manager: null
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [apiKey, setApiKey] = useState('GCP-HEALTH-TEST-KEY'); // Clave fija predeterminada
  const [showMessage, setShowMessage] = useState(false);
  const [message, setMessage] = useState('');

  const checkHealth = async () => {
    if (!apiKey.trim()) {
      setMessage('Please enter an API key');
      setShowMessage(true);
      return;
    }

    try {
      setLoading(true);
      const response = await fetch(`${BACKEND_URL}/health`, {
        method: 'GET', 
        headers: {
          'x-api-key': apiKey
        }
      });

      if (!response.ok) {
        throw new Error(`Backend responded with status ${response.status}`);
      }

      const data = await response.json();
      setHealthData(data);
      setError(null);
    } catch (err) {
      setError(err.message);
      // Don't clear healthData on error, keep showing previous status
      setMessage(`Failed to fetch health status: ${err.message}`);
      setShowMessage(true);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (apiKey) {
      checkHealth();
    }
  }, [apiKey]);

  // Map service names to display names
  const serviceDisplayNames = {
    vertex_ai_gemini: 'Vertex AI Gemini',
    vertex_ai_index: 'Vertex AI Vector Search',
    document_ai: 'Document AI',
    cloud_storage: 'Cloud Storage',
    cloud_sql: 'Cloud SQL',
    firestore: 'Firestore Database',
    secret_manager: 'Secret Manager'
  };

  return (
    <>
      <AppBar position="static" color="transparent" elevation={0}>
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            GCP System Status
          </Typography>
          <ApiKeyInput
            apiKey={apiKey}
            setApiKey={setApiKey}
            disabled={loading}
          />
          <Button
            onClick={checkHealth}
            color="primary"
            variant="contained"
            disabled={loading || !apiKey.trim()}
            sx={{ ml: 2 }}
          >
            Refresh Status
          </Button>
        </Toolbar>
      </AppBar>

      <Container maxWidth="lg" sx={{ py: 4 }}>
        <WelcomeHeader />

        {!apiKey.trim() ? (
          <Paper
            elevation={3}
            sx={{
              p: 3,
              mt: 4,
              textAlign: 'center',
              backgroundColor: '#f5f5f5'
            }}
          >
            <Typography variant="h6" gutterBottom>
              Welcome to the GCP Health Dashboard
            </Typography>
            <Typography color="text.secondary">
              Please enter your API key in the top bar to check the health status of your GCP services.
            </Typography>
          </Paper>
        ) : loading && !Object.values(healthData).some(value => value !== null) ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            {error && (
              <Paper
                elevation={3}
                sx={{
                  p: 3,
                  mb: 4,
                  backgroundColor: '#fff3f3'
                }}
              >
                <Typography color="error" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <ErrorIcon /> {error}
                </Typography>
              </Paper>
            )}

            <Grid container spacing={3}>
              {/* First row: AI services */}
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.vertex_ai_gemini} health={healthData?.vertex_ai_gemini} />
              </Grid>
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.vertex_ai_index} health={healthData?.vertex_ai_index} />
              </Grid>
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.document_ai} health={healthData?.document_ai} />
              </Grid>
              
              {/* Second row: Storage services */}
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.cloud_storage} health={healthData?.cloud_storage} />
              </Grid>
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.firestore} health={healthData?.firestore} />
              </Grid>
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.cloud_sql} health={healthData?.cloud_sql} />
              </Grid>
              
              {/* Third row: Security services */}
              <Grid item xs={12} md={6}>
                <ServiceHealth name={serviceDisplayNames.secret_manager} health={healthData?.secret_manager} />
              </Grid>
            </Grid>
          </>
        )}
      </Container>

      {/* Footer */}
      <Box
        component="footer"
        sx={{
          py: 3,
          mt: 'auto',
          textAlign: 'center',
          color: 'text.secondary',
          fontSize: '0.875rem'
        }}
      >
        made with ❤️ mash
      </Box>

      <Snackbar
        open={showMessage}
        autoHideDuration={6000}
        onClose={() => setShowMessage(false)}
        message={message}
      />
    </>
  );
}

export default App;