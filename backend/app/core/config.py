"""
Configuration settings for the timing backend
"""
from pydantic_settings import BaseSettings
from typing import Optional
import os
from datetime import datetime


class Settings(BaseSettings):
    # Server settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True
    
    # Database settings
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/timing_db"
    
    # Redis settings
    REDIS_URL: str = "redis://localhost:6379"
    
    # Firebase settings
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None
    FIREBASE_PROJECT_ID: str = "kartingapp-fef5c"
    
    # WebSocket settings
    WS_HEARTBEAT_INTERVAL: int = 30
    WS_RECONNECT_DELAY: int = 5
    WS_MAX_RECONNECT_ATTEMPTS: int = 10
    
    # Analysis settings
    ANALYSIS_DURATION: int = 60  # seconds
    ANALYSIS_MIN_SAMPLES: int = 10
    ANALYSIS_TIMEOUT: int = 120  # seconds
    
    # Security
    SECRET_KEY: str = "your-secret-key-here"
    CORS_ORIGINS: list = [
        "http://localhost:3000",
        "http://localhost:53533",  # Flutter web dev
        "http://127.0.0.1:3000",
        "http://172.25.147.11:3000",
        "https://kartingapp-fef5c.web.app"
    ]
    
    # Logging
    LOG_LEVEL: str = "INFO"
    
    def get_current_timestamp(self) -> str:
        """Get current UTC timestamp in ISO format"""
        return datetime.utcnow().isoformat()
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()