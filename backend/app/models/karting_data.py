"""
Data models for karting timing information
"""
from typing import Dict, Any, Optional, List
from datetime import datetime
from pydantic import BaseModel, Field


class KartingColumn(BaseModel):
    """Represents a single karting data column (C1-C14)"""
    code: str = Field(..., description="Column code from WebSocket")
    value: str = Field(..., description="Column value")
    column_number: str = Field(..., description="Column number (1-14)")
    timestamp: Optional[str] = Field(None, description="When this value was received")


class RawKartingUpdate(BaseModel):
    """Raw karting data update from WebSocket"""
    driver_id: str = Field(..., description="Driver identifier")
    raw_columns: Dict[str, KartingColumn] = Field(default_factory=dict, description="Raw C1-C14 data")
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class DriverTimingData(BaseModel):
    """Complete driver timing data (mapped from C1-C14)"""
    driver_id: str = Field(..., description="Driver identifier")
    
    # Timing fields (mapped from circuit configuration)
    position: Optional[str] = Field(None, description="Current position/classement")
    kart_number: Optional[str] = Field(None, description="Kart number")
    driver_name: Optional[str] = Field(None, description="Driver/team name")
    last_lap_time: Optional[str] = Field(None, description="Last lap time")
    best_lap_time: Optional[str] = Field(None, description="Best lap time")
    gap: Optional[str] = Field(None, description="Gap to leader")
    laps: Optional[str] = Field(None, description="Number of laps")
    sector_1: Optional[str] = Field(None, description="Sector 1 time")
    sector_2: Optional[str] = Field(None, description="Sector 2 time")
    sector_3: Optional[str] = Field(None, description="Sector 3 time")
    
    # Additional mapped fields (depends on circuit configuration)
    additional_fields: Dict[str, str] = Field(default_factory=dict, description="Other mapped fields")
    
    # Metadata
    last_update: str = Field(default_factory=lambda: datetime.now().isoformat())
    has_websocket_data: bool = Field(False, description="Has live WebSocket data")
    has_static_data: bool = Field(False, description="Has static data")
    
    # Raw data for debugging
    raw_columns: Optional[Dict[str, KartingColumn]] = Field(None, description="Raw column data")


class CircuitMappings(BaseModel):
    """Circuit-specific C1-C14 mappings"""
    circuit_id: str = Field(..., description="Circuit identifier")
    circuit_name: Optional[str] = Field(None, description="Circuit name")
    mappings: Dict[str, str] = Field(..., description="C1-C14 to field name mappings")
    
    # WebSocket connection info
    websocket_url: Optional[str] = Field(None, description="WebSocket URL for live timing")
    live_timing_url: Optional[str] = Field(None, description="HTTP URL for timing page")
    
    # Metadata
    created_at: Optional[str] = Field(None, description="When mappings were created")
    last_updated: Optional[str] = Field(None, description="When mappings were last updated")


class SessionState(BaseModel):
    """Complete session state"""
    circuit_id: str = Field(..., description="Current circuit ID")
    circuit_mappings: CircuitMappings = Field(..., description="Circuit configuration")
    
    # Driver data
    drivers: Dict[str, DriverTimingData] = Field(default_factory=dict, description="All driver states")
    active_drivers: List[str] = Field(default_factory=list, description="Drivers with recent data")
    
    # Session statistics
    total_updates: int = Field(0, description="Total WebSocket updates processed")
    last_websocket_update: Optional[str] = Field(None, description="Last WebSocket update time")
    last_static_update: Optional[str] = Field(None, description="Last static data update time")
    session_start: str = Field(default_factory=lambda: datetime.now().isoformat())


class ParseResult(BaseModel):
    """Result of parsing a WebSocket message"""
    success: bool = Field(..., description="Whether parsing was successful")
    drivers_updated: List[str] = Field(default_factory=list, description="Drivers that were updated")
    mapped_data: Dict[str, DriverTimingData] = Field(default_factory=dict, description="Parsed and mapped data")
    raw_updates: Dict[str, RawKartingUpdate] = Field(default_factory=dict, description="Raw parsed updates")
    
    # Metadata
    message_count: int = Field(0, description="Total messages processed")
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    error: Optional[str] = Field(None, description="Error message if parsing failed")


class WebSocketMessage(BaseModel):
    """WebSocket message to send to clients"""
    type: str = Field(..., description="Message type")
    circuit_id: str = Field(..., description="Circuit ID")
    
    # Timing data
    drivers: Optional[Dict[str, DriverTimingData]] = Field(None, description="Driver timing data")
    updated_drivers: Optional[List[str]] = Field(None, description="List of updated driver IDs")
    
    # Session info
    session_stats: Optional[Dict[str, Any]] = Field(None, description="Session statistics")
    
    # Metadata
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class KartingStatistics(BaseModel):
    """Statistics for monitoring karting system"""
    # Driver counts
    total_drivers: int = Field(0, description="Total drivers in session")
    active_drivers: int = Field(0, description="Drivers with recent WebSocket data")
    drivers_with_static_data: int = Field(0, description="Drivers with static data")
    
    # Message counts
    total_messages: int = Field(0, description="Total WebSocket messages processed")
    successful_parses: int = Field(0, description="Successfully parsed messages")
    failed_parses: int = Field(0, description="Failed message parses")
    
    # Timing
    last_websocket_update: Optional[str] = Field(None, description="Last WebSocket update")
    last_static_update: Optional[str] = Field(None, description="Last static data update")
    session_duration: Optional[str] = Field(None, description="Session duration")
    
    # Circuit info
    circuit_id: Optional[str] = Field(None, description="Current circuit")
    mappings_count: int = Field(0, description="Number of active C1-C14 mappings")
    
    # Performance
    average_parse_time: Optional[float] = Field(None, description="Average message parse time (ms)")
    messages_per_second: Optional[float] = Field(None, description="Message processing rate")


# Common field mappings for different circuit types
COMMON_FIELD_MAPPINGS = {
    "apex_timing": {
        "C1": "Classement",
        "C2": "Kart", 
        "C3": "Equipe/Pilote",
        "C4": "Dernier T.",
        "C5": "Ecart",
        "C6": "Meilleur T.",
        "C7": "Tour",
        "C8": "S1",
        "C9": "S2", 
        "C10": "S3",
        "C11": "Non utilisé",
        "C12": "Non utilisé",
        "C13": "Non utilisé",
        "C14": "Non utilisé"
    },
    "mylaps": {
        "C1": "Position",
        "C2": "Number",
        "C3": "Driver",
        "C4": "Lap Time",
        "C5": "Best Time", 
        "C6": "Gap",
        "C7": "Laps",
        "C8": "Non utilisé",
        "C9": "Non utilisé",
        "C10": "Non utilisé",
        "C11": "Non utilisé",
        "C12": "Non utilisé",
        "C13": "Non utilisé",
        "C14": "Non utilisé"
    }
}


def create_circuit_mappings(circuit_id: str, mapping_type: str = "apex_timing") -> CircuitMappings:
    """
    Create circuit mappings using a predefined template
    
    Args:
        circuit_id: Circuit identifier
        mapping_type: Type of mapping template to use
        
    Returns:
        CircuitMappings instance
    """
    mappings = COMMON_FIELD_MAPPINGS.get(mapping_type, COMMON_FIELD_MAPPINGS["apex_timing"])
    
    return CircuitMappings(
        circuit_id=circuit_id,
        mappings=mappings,
        created_at=datetime.now().isoformat()
    )