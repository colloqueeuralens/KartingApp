"""
Database models for timing data
"""
from sqlalchemy import Column, String, DateTime, Integer, Text, JSON, Boolean, Float
from sqlalchemy.sql import func
from ..core.database import Base
from pydantic import BaseModel
from typing import Dict, Any, Optional
from datetime import datetime


class TimingData(Base):
    """Store live timing data"""
    __tablename__ = "timing_data"
    
    id = Column(Integer, primary_key=True, index=True)
    circuit_id = Column(String, index=True, nullable=False)
    session_id = Column(String, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    data_type = Column(String)  # 'position', 'lap_time', 'sector_time', etc.
    
    # Mapped data according to C1-C14 configuration
    mapped_data = Column(JSON)
    
    # Raw data from timing source
    raw_data = Column(JSON)
    
    # Source information
    source_url = Column(String)
    source_format = Column(String)


class CircuitAnalysis(Base):
    """Store circuit analysis results"""
    __tablename__ = "circuit_analysis"
    
    id = Column(Integer, primary_key=True, index=True)
    circuit_id = Column(String, unique=True, index=True, nullable=False)
    websocket_url = Column(String, nullable=False)
    
    # Analysis results
    detected_format = Column(String)  # 'json', 'text', 'binary'
    message_structure = Column(JSON)  # Detected structure
    update_frequency = Column(Float)  # Messages per second
    patterns = Column(JSON)  # Detected patterns (time, position, etc.)
    
    # Generated parser
    parser_code = Column(Text)
    parser_version = Column(String)
    
    # Metadata
    samples_analyzed = Column(Integer)
    analysis_duration = Column(Integer)  # seconds
    last_analyzed = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=False)


class ConnectionLog(Base):
    """Log connection events"""
    __tablename__ = "connection_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    circuit_id = Column(String, index=True, nullable=False)
    event_type = Column(String)  # 'connect', 'disconnect', 'error', 'reconnect'
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    message = Column(Text)
    details = Column(JSON)


# Pydantic models for API
class TimingDataResponse(BaseModel):
    """Response model for timing data"""
    circuit_id: str
    timestamp: datetime
    mapped_data: Dict[str, Any]
    data_type: Optional[str] = None
    
    class Config:
        from_attributes = True


class CircuitStatus(BaseModel):
    """Circuit connection status"""
    circuit_id: str
    is_active: bool
    last_update: Optional[datetime] = None
    connected_clients: int = 0
    source_url: Optional[str] = None
    detected_format: Optional[str] = None
    update_frequency: Optional[float] = None


class AnalysisResult(BaseModel):
    """Analysis result model"""
    circuit_id: str
    websocket_url: str
    detected_format: str
    message_structure: Dict[str, Any]
    patterns: Dict[str, Any]
    update_frequency: float
    samples_analyzed: int
    analysis_duration: int
    success: bool
    error_message: Optional[str] = None