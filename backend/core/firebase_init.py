import firebase_admin
from firebase_admin import credentials, firestore
from core.config import settings

import os
import tempfile

def init_firebase():
    if not firebase_admin._apps:
        try:
            # If GCP_ADC_JSON env var is set (for Railway/cloud deployments), write to a temp file
            # and set GOOGLE_APPLICATION_CREDENTIALS so ApplicationDefault() can pick it up.
            adc_json = os.getenv("GCP_ADC_JSON")
            if adc_json:
                fd, path = tempfile.mkstemp(suffix=".json")
                with os.fdopen(fd, 'w') as f:
                    f.write(adc_json)
                os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = path
                print(f"Set GOOGLE_APPLICATION_CREDENTIALS to temp file: {path}")

            # Use Application Default Credentials (ADC)
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {
                'projectId': 'kaarobar-ai', # Your explicit project ID
            })
            print("Successfully connected to Firebase via ADC!")
        except Exception as e:
            print(f"Warning: Firebase could not be initialized via ADC. Error: {e}")

# Initialize at startup
init_firebase()

def get_db():
    if firebase_admin._apps:
        return firestore.client()
    return None
