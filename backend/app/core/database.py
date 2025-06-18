"""
Database configuration and session management
"""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from contextlib import asynccontextmanager
import firebase_admin
from firebase_admin import credentials, firestore
from .config import settings
import structlog

logger = structlog.get_logger(__name__)


class Base(DeclarativeBase):
    """Base class for SQLAlchemy models"""
    pass


# PostgreSQL setup
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True
)

async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)


@asynccontextmanager
async def get_db_session():
    """Async context manager for database sessions"""
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Firebase setup
class FirebaseManager:
    """Firebase Firestore connection manager"""
    
    def __init__(self):
        self.db = None
        self._initialized = False
    
    def initialize(self):
        """Initialize Firebase connection"""
        if self._initialized:
            return
        
        try:
            if settings.FIREBASE_CREDENTIALS_PATH:
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred, {
                    'projectId': settings.FIREBASE_PROJECT_ID,
                })
            else:
                # Use default credentials (for deployment)
                firebase_admin.initialize_app()
            
            self.db = firestore.client()
            self._initialized = True
            logger.info("Firebase initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")
            raise
    
    def get_db(self):
        """Get Firestore database instance"""
        if not self._initialized:
            self.initialize()
        return self.db


# Global Firebase instance
firebase_manager = FirebaseManager()


async def init_database():
    """Initialize database connections"""
    try:
        # Initialize Firebase
        firebase_manager.initialize()
        
        # Test PostgreSQL connection
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        
        logger.info("Database connections initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize databases: {e}")
        raise


async def close_database():
    """Close database connections"""
    try:
        await engine.dispose()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error(f"Error closing database connections: {e}")