import firebase_admin
from firebase_admin import credentials, firestore
from core.config import settings

def init_firebase():
    if not firebase_admin._apps:
        try:
            # Use Application Default Credentials (ADC) since you installed Google Cloud CLI
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
