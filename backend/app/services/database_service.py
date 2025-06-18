"""
Database service for timing data operations
"""
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, and_, func
from sqlalchemy.dialects.postgresql import insert
import structlog

from ..core.database import get_db_session, async_session
from ..models.timing_data import TimingData, CircuitAnalysis, ConnectionLog

logger = structlog.get_logger(__name__)


class DatabaseService:
    """Service for database operations"""
    
    async def store_timing_data(self, timing_data: Dict[str, Any]) -> int:
        """Store timing data in database"""
        try:
            async with get_db_session() as session:
                db_data = TimingData(
                    circuit_id=timing_data['circuit_id'],
                    session_id=timing_data.get('session_id'),
                    data_type=timing_data.get('data_type', 'live_timing'),
                    mapped_data=timing_data.get('mapped_data', {}),
                    raw_data=timing_data.get('raw_data', {}),
                    source_url=timing_data.get('source_url'),
                    source_format=timing_data.get('source_format'),
                    timestamp=datetime.fromisoformat(timing_data['timestamp'].replace('Z', '+00:00'))
                    if isinstance(timing_data.get('timestamp'), str)
                    else timing_data.get('timestamp', datetime.utcnow())
                )
                
                session.add(db_data)
                await session.flush()
                return db_data.id
                
        except Exception as e:
            logger.error(f"Error storing timing data: {e}")
            raise
    
    async def get_recent_timing_data(self, circuit_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """Get recent timing data for a circuit"""
        try:
            async with get_db_session() as session:
                query = (
                    select(TimingData)
                    .where(TimingData.circuit_id == circuit_id)
                    .order_by(desc(TimingData.timestamp))
                    .limit(limit)
                )
                
                result = await session.execute(query)
                data = result.scalars().all()
                
                return [
                    {
                        'id': item.id,
                        'circuit_id': item.circuit_id,
                        'timestamp': item.timestamp.isoformat(),
                        'data_type': item.data_type,
                        'mapped_data': item.mapped_data,
                        'raw_data': item.raw_data,
                        'source_url': item.source_url
                    }
                    for item in data
                ]
                
        except Exception as e:
            logger.error(f"Error fetching timing data: {e}")
            return []
    
    async def get_timing_data_by_timerange(self, circuit_id: str, 
                                         start_time: datetime, 
                                         end_time: datetime) -> List[Dict[str, Any]]:
        """Get timing data within a time range"""
        try:
            async with get_db_session() as session:
                query = (
                    select(TimingData)
                    .where(
                        and_(
                            TimingData.circuit_id == circuit_id,
                            TimingData.timestamp >= start_time,
                            TimingData.timestamp <= end_time
                        )
                    )
                    .order_by(TimingData.timestamp)
                )
                
                result = await session.execute(query)
                data = result.scalars().all()
                
                return [
                    {
                        'id': item.id,
                        'circuit_id': item.circuit_id,
                        'timestamp': item.timestamp.isoformat(),
                        'data_type': item.data_type,
                        'mapped_data': item.mapped_data,
                        'raw_data': item.raw_data
                    }
                    for item in data
                ]
                
        except Exception as e:
            logger.error(f"Error fetching timing data by time range: {e}")
            return []
    
    async def store_circuit_analysis(self, analysis_data: Dict[str, Any]) -> int:
        """Store or update circuit analysis"""
        try:
            async with get_db_session() as session:
                # Use PostgreSQL UPSERT
                stmt = insert(CircuitAnalysis).values(
                    circuit_id=analysis_data['circuit_id'],
                    websocket_url=analysis_data['websocket_url'],
                    detected_format=analysis_data.get('detected_format'),
                    message_structure=analysis_data.get('message_structure', {}),
                    update_frequency=analysis_data.get('update_frequency', 0.0),
                    patterns=analysis_data.get('patterns', {}),
                    parser_code=analysis_data.get('parser_code'),
                    parser_version=analysis_data.get('parser_version', '1.0'),
                    samples_analyzed=analysis_data.get('samples_analyzed', 0),
                    analysis_duration=analysis_data.get('analysis_duration', 0),
                    is_active=analysis_data.get('is_active', True)
                )
                
                stmt = stmt.on_conflict_do_update(
                    index_elements=['circuit_id'],
                    set_=dict(
                        websocket_url=stmt.excluded.websocket_url,
                        detected_format=stmt.excluded.detected_format,
                        message_structure=stmt.excluded.message_structure,
                        update_frequency=stmt.excluded.update_frequency,
                        patterns=stmt.excluded.patterns,
                        parser_code=stmt.excluded.parser_code,
                        parser_version=stmt.excluded.parser_version,
                        samples_analyzed=stmt.excluded.samples_analyzed,
                        analysis_duration=stmt.excluded.analysis_duration,
                        last_analyzed=func.now(),
                        is_active=stmt.excluded.is_active
                    )
                )
                
                result = await session.execute(stmt)
                return result.inserted_primary_key[0] if result.inserted_primary_key else None
                
        except Exception as e:
            logger.error(f"Error storing circuit analysis: {e}")
            raise
    
    async def get_circuit_analysis(self, circuit_id: str) -> Optional[Dict[str, Any]]:
        """Get circuit analysis data"""
        try:
            async with get_db_session() as session:
                query = select(CircuitAnalysis).where(CircuitAnalysis.circuit_id == circuit_id)
                result = await session.execute(query)
                analysis = result.scalar_one_or_none()
                
                if analysis:
                    return {
                        'circuit_id': analysis.circuit_id,
                        'websocket_url': analysis.websocket_url,
                        'detected_format': analysis.detected_format,
                        'message_structure': analysis.message_structure,
                        'update_frequency': analysis.update_frequency,
                        'patterns': analysis.patterns,
                        'parser_code': analysis.parser_code,
                        'parser_version': analysis.parser_version,
                        'samples_analyzed': analysis.samples_analyzed,
                        'analysis_duration': analysis.analysis_duration,
                        'last_analyzed': analysis.last_analyzed.isoformat() if analysis.last_analyzed else None,
                        'is_active': analysis.is_active
                    }
                
                return None
                
        except Exception as e:
            logger.error(f"Error fetching circuit analysis: {e}")
            return None
    
    async def log_connection_event(self, circuit_id: str, event_type: str, 
                                 message: str, details: Dict[str, Any] = None):
        """Log connection events"""
        try:
            async with get_db_session() as session:
                log_entry = ConnectionLog(
                    circuit_id=circuit_id,
                    event_type=event_type,
                    message=message,
                    details=details or {}
                )
                
                session.add(log_entry)
                
        except Exception as e:
            logger.error(f"Error logging connection event: {e}")
    
    async def get_connection_logs(self, circuit_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get recent connection logs for a circuit"""
        try:
            async with get_db_session() as session:
                query = (
                    select(ConnectionLog)
                    .where(ConnectionLog.circuit_id == circuit_id)
                    .order_by(desc(ConnectionLog.timestamp))
                    .limit(limit)
                )
                
                result = await session.execute(query)
                logs = result.scalars().all()
                
                return [
                    {
                        'id': log.id,
                        'circuit_id': log.circuit_id,
                        'event_type': log.event_type,
                        'timestamp': log.timestamp.isoformat(),
                        'message': log.message,
                        'details': log.details
                    }
                    for log in logs
                ]
                
        except Exception as e:
            logger.error(f"Error fetching connection logs: {e}")
            return []
    
    async def cleanup_old_data(self, days_to_keep: int = 7):
        """Clean up old timing data"""
        try:
            cutoff_date = datetime.utcnow() - timedelta(days=days_to_keep)
            
            async with get_db_session() as session:
                # Delete old timing data
                timing_query = select(TimingData).where(TimingData.timestamp < cutoff_date)
                timing_result = await session.execute(timing_query)
                old_timing_data = timing_result.scalars().all()
                
                for data in old_timing_data:
                    await session.delete(data)
                
                # Delete old connection logs
                log_query = select(ConnectionLog).where(ConnectionLog.timestamp < cutoff_date)
                log_result = await session.execute(log_query)
                old_logs = log_result.scalars().all()
                
                for log in old_logs:
                    await session.delete(log)
                
                logger.info(f"Cleaned up {len(old_timing_data)} timing records and {len(old_logs)} log entries")
                
        except Exception as e:
            logger.error(f"Error during data cleanup: {e}")
    
    async def get_circuit_statistics(self, circuit_id: str) -> Dict[str, Any]:
        """Get statistics for a circuit"""
        try:
            async with get_db_session() as session:
                # Get timing data count
                timing_count_query = select(func.count(TimingData.id)).where(
                    TimingData.circuit_id == circuit_id
                )
                timing_count = await session.scalar(timing_count_query)
                
                # Get latest timing data
                latest_query = (
                    select(TimingData.timestamp)
                    .where(TimingData.circuit_id == circuit_id)
                    .order_by(desc(TimingData.timestamp))
                    .limit(1)
                )
                latest_timestamp = await session.scalar(latest_query)
                
                # Get data from last 24 hours
                last_24h = datetime.utcnow() - timedelta(hours=24)
                recent_count_query = select(func.count(TimingData.id)).where(
                    and_(
                        TimingData.circuit_id == circuit_id,
                        TimingData.timestamp >= last_24h
                    )
                )
                recent_count = await session.scalar(recent_count_query)
                
                return {
                    'circuit_id': circuit_id,
                    'total_records': timing_count or 0,
                    'recent_records_24h': recent_count or 0,
                    'latest_data_timestamp': latest_timestamp.isoformat() if latest_timestamp else None,
                    'is_active': (datetime.utcnow() - latest_timestamp).total_seconds() < 300
                    if latest_timestamp else False
                }
                
        except Exception as e:
            logger.error(f"Error getting circuit statistics: {e}")
            return {
                'circuit_id': circuit_id,
                'total_records': 0,
                'recent_records_24h': 0,
                'latest_data_timestamp': None,
                'is_active': False
            }


# Global database service instance
db_service = DatabaseService()