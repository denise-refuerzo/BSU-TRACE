import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://username:password@localhost:5432/bsutrace")
    # Add this new line to read the ML database string from your .env file
    ML_DATABASE_URL: str = os.getenv("ML_DATABASE_URL")

settings = Settings()