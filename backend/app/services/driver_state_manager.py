"""
Driver state manager for hybrid data (WebSocket + Firebase static data)
Inspired by drivers.py hybrid data management approach
"""
import json
import asyncio
from typing import Dict, Any, Optional, Set, List
from datetime import datetime
from collections import OrderedDict
import structlog

from ..analyzers.karting_parser import KartingMessageParser
from .firebase_sync import firebase_sync

logger = structlog.get_logger(__name__)


class DriverStateManager:
    """
    Manages hybrid driver data combining WebSocket timing with Firebase static data
    Inspired by drivers.py approach of merging raw_data + drivers
    """
    
    def __init__(self):
        # WebSocket timing data parser
        self.karting_parser: Optional[KartingMessageParser] = None
        
        # Static data from Firebase (kart numbers, driver names, etc.)
        self.static_data: Dict[str, Dict[str, Any]] = {}
        
        # Final merged driver states (equivalent to drivers.py drivers after remapping)
        self.merged_states: Dict[str, Dict[str, Any]] = {}
        
        # Current circuit mappings (C1-C14)
        self.current_circuit_mappings: Dict[str, str] = {}
        
        # Circuit ID for context
        self.current_circuit_id: Optional[str] = None
        
        
        # Update locks for thread safety
        self._lock = asyncio.Lock()
        
        # Statistics
        self.last_websocket_update = None
        self.last_static_update = None
        self.total_updates = 0
        
        logger.info("DriverStateManager initialized")
    
    async def initialize_circuit(self, circuit_id: str) -> bool:
        """
        Initialize for a specific circuit with its mappings
        
        Args:
            circuit_id: Circuit ID to load mappings for
            
        Returns:
            True if successfully initialized
        """
        async with self._lock:
            try:
                self.current_circuit_id = circuit_id
                
                # Load circuit mappings from Firebase
                circuit_data = await firebase_sync.get_circuit_with_mappings(circuit_id)
                if not circuit_data:
                    logger.error(f"Circuit {circuit_id} not found")
                    return False
                
                # Extract C1-C14 mappings
                mappings = {}
                for i in range(1, 15):
                    column_key = f"c{i}"
                    if column_key in circuit_data and circuit_data[column_key]:
                        mappings[f"C{i}"] = circuit_data[column_key]
                
                self.current_circuit_mappings = mappings
                
                # Initialize karting parser with circuit mappings
                self.karting_parser = KartingMessageParser(mappings)
                
                # Load any existing static data for this circuit
                await self._load_static_data()
                
                logger.info(f"Initialized circuit {circuit_id} with {len(mappings)} mappings")
                return True
                
            except Exception as e:
                logger.error(f"Failed to initialize circuit {circuit_id}: {e}")
                return False
    
    async def process_websocket_message(self, message: str) -> Dict[str, Any]:
        """
        Process WebSocket message and update driver states
        
        Args:
            message: Raw WebSocket message
            
        Returns:
            Dictionary with processing results and updated drivers
        """
        if not self.karting_parser:
            return {'error': 'Parser not initialized - call initialize_circuit first'}
        
        async with self._lock:
            try:
                # Parse WebSocket message
                parse_result = self.karting_parser.parse_message(message)
                
                if not parse_result['success']:
                    return parse_result
                
                # Update statistics
                self.last_websocket_update = datetime.now()
                self.total_updates += 1
                
                # Merge with static data and update final states
                updated_drivers = await self._merge_websocket_updates(
                    parse_result['drivers_updated'],
                    parse_result['mapped_data']
                )
                
                result = {
                    'success': True,
                    'drivers_updated': list(updated_drivers),
                    'updated_states': {
                        driver_id: self.merged_states[driver_id]
                        for driver_id in updated_drivers
                        if driver_id in self.merged_states
                    },
                    'parse_stats': {
                        'message_count': parse_result['message_count'],
                        'timestamp': parse_result['timestamp']
                    }
                }
                
                logger.debug(f"Processed WebSocket update for {len(updated_drivers)} drivers")
                return result
                
            except Exception as e:
                logger.error(f"Error processing WebSocket message: {e}")
                return {'error': str(e)}
    
    async def update_static_data(self, driver_id: str, data: Dict[str, Any]):
        """
        Update static data for a driver (from Firebase or other sources)
        
        Args:
            driver_id: Driver ID
            data: Static data (kart number, driver name, etc.)
        """
        async with self._lock:
            if driver_id not in self.static_data:
                self.static_data[driver_id] = {}
            
            self.static_data[driver_id].update(data)
            self.last_static_update = datetime.now()
            
            # Trigger merge for this driver
            await self._merge_single_driver(driver_id)
            
            logger.debug(f"Updated static data for driver {driver_id}")
    
    
    async def _load_static_data(self):
        """Load static data from Firebase for current circuit"""
        try:
            # This could be extended to load circuit-specific driver info
            # For now, we'll start with empty static data that gets populated as needed
            self.static_data = {}
            logger.info("Static data loaded (empty - will populate as needed)")
            
        except Exception as e:
            logger.error(f"Error loading static data: {e}")
    
    async def _merge_websocket_updates(self, driver_ids: Set[str], mapped_data: Dict[str, Dict[str, Any]]) -> Set[str]:
        """
        Merge WebSocket updates with static data
        Equivalent to drivers.py remap_drivers() logic
        """
        updated_drivers = set()
        
        for driver_id in driver_ids:
            if driver_id in mapped_data:
                await self._merge_single_driver(driver_id, mapped_data[driver_id])
                updated_drivers.add(driver_id)
        
        return updated_drivers
    
    async def _merge_single_driver(self, driver_id: str, websocket_data: Optional[Dict[str, Any]] = None):
        """
        Merge data for a single driver (WebSocket + static)
        Inspired by drivers.py combined_data logic
        """
        # Start with existing merged state or empty
        merged_driver = self.merged_states.get(driver_id, {'driver_id': driver_id})
        
        # Add static data (kart, driver name, etc.)
        if driver_id in self.static_data:
            for key, value in self.static_data[driver_id].items():
                merged_driver[key] = value
        
        # Add/update WebSocket data
        if websocket_data:
            for key, value in websocket_data.items():
                if not key.endswith('_raw'):  # Skip raw debug data
                    merged_driver[key] = value
        
        # Add metadata
        merged_driver['last_update'] = datetime.now().isoformat()
        merged_driver['has_websocket_data'] = websocket_data is not None
        merged_driver['has_static_data'] = driver_id in self.static_data
        
        # Store merged state
        self.merged_states[driver_id] = merged_driver
    
    def get_driver_state(self, driver_id: str) -> Optional[Dict[str, Any]]:
        """Get complete merged state for a driver"""
        return self.merged_states.get(driver_id)
    
    def get_all_driver_states(self) -> Dict[str, Dict[str, Any]]:
        """Get all merged driver states"""
        return self.merged_states.copy()
    
    def get_active_drivers(self) -> List[str]:
        """Get list of drivers with recent WebSocket data"""
        if not self.karting_parser:
            return []
        
        # Return drivers that have WebSocket data
        return list(self.karting_parser.get_all_driver_states().keys())
    
    async def clear_session_data(self):
        """Clear all session data"""
        async with self._lock:
            if self.karting_parser:
                self.karting_parser.clear_all_data()
            self.static_data.clear()
            self.merged_states.clear()
            self.total_updates = 0
            logger.info("Cleared all session data")
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get manager statistics"""
        parser_stats = {}
        if self.karting_parser:
            parser_stats = self.karting_parser.get_statistics()
        
        return {
            'circuit_id': self.current_circuit_id,
            'total_drivers': len(self.merged_states),
            'active_drivers': len(self.get_active_drivers()),
            'static_data_count': len(self.static_data),
            'total_updates': self.total_updates,
            'last_websocket_update': self.last_websocket_update.isoformat() if self.last_websocket_update else None,
            'last_static_update': self.last_static_update.isoformat() if self.last_static_update else None,
            'circuit_mappings': len(self.current_circuit_mappings),
            'parser_stats': parser_stats,
        }
    
    async def export_session(self) -> Dict[str, Any]:
        """
        Export complete session data for persistence
        Equivalent to drivers.py save_drivers_to_file()
        """
        session_data = {
            'circuit_id': self.current_circuit_id,
            'circuit_mappings': self.current_circuit_mappings,
            'static_data': self.static_data,
            'merged_states': self.merged_states,
            'statistics': self.get_statistics(),
            'export_timestamp': datetime.now().isoformat()
        }
        
        # Add parser data if available
        if self.karting_parser:
            session_data['parser_data'] = self.karting_parser.export_session_data()
        
        return session_data
    
    async def import_session(self, session_data: Dict[str, Any]) -> bool:
        """Import session data from persistence"""
        try:
            async with self._lock:
                if 'circuit_id' in session_data:
                    self.current_circuit_id = session_data['circuit_id']
                
                if 'circuit_mappings' in session_data:
                    self.current_circuit_mappings = session_data['circuit_mappings']
                    
                    # Reinitialize parser with mappings
                    self.karting_parser = KartingMessageParser(self.current_circuit_mappings)
                
                if 'static_data' in session_data:
                    self.static_data = session_data['static_data']
                
                if 'merged_states' in session_data:
                    self.merged_states = session_data['merged_states']
                
                # Import parser data if available
                if self.karting_parser and 'parser_data' in session_data:
                    self.karting_parser.import_session_data(session_data['parser_data'])
                
                logger.info(f"Imported session for circuit {self.current_circuit_id}")
                return True
                
        except Exception as e:
            logger.error(f"Error importing session: {e}")
            return False


# Global instance for the application
driver_state_manager = DriverStateManager()