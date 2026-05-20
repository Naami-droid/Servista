import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "Karobar AI"
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    XAI_API_KEY: str = os.getenv("XAI_API_KEY", "")
    SENDGRID_API_KEY: str = os.getenv("SENDGRID_API_KEY", "")
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-adminsdk.json")

settings = Settings()
