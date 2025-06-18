"""
Base collector class for timing data
"""
import asyncio
import time
import websockets
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Callable, List
from datetime import datetime
import json
import structlog
from ..core.config import settings

logger = structlog.get_logger(__name__)


class BaseCollector(ABC):
    """Base class for timing data collectors"""
    
    def __init__(self, circuit_id: str, websocket_url: str, parser_code: str = None, circuit_config: Dict[str, Any] = None):
        self.circuit_id = circuit_id
        self.websocket_url = websocket_url
        self.parser_code = parser_code
        self.parser = None
        self.circuit_config = circuit_config or {}
        
        # Connection state
        self.is_running = False
        self.is_connected = False
        self.reconnect_attempts = 0
        self.last_message_time = None
        
        # Callbacks
        self.on_data_callback = None
        self.on_error_callback = None
        self.on_connection_change_callback = None
        
        # Data caching
        self.last_data = None
        self.message_count = 0
        
        # Create parser if code provided
        if parser_code:
            self._create_parser(parser_code)
    
    def set_callbacks(self, 
                     on_data: Callable[[Dict[str, Any]], None] = None,
                     on_error: Callable[[str], None] = None,
                     on_connection_change: Callable[[bool], None] = None):
        """Set callback functions for events"""
        self.on_data_callback = on_data
        self.on_error_callback = on_error
        self.on_connection_change_callback = on_connection_change
    
    def _create_parser(self, parser_code: str):
        """Create parser from generated code"""
        try:
            # Execute the parser code in a safe namespace
            namespace = {}
            exec(parser_code, namespace)
            
            # Get the GeneratedParser class
            parser_class = namespace.get('GeneratedParser')
            if parser_class:
                self.parser = parser_class()
                logger.info(f"Parser created for circuit {self.circuit_id}")
            else:
                logger.error("GeneratedParser class not found in parser code")
                
        except Exception as e:
            logger.error(f"Failed to create parser: {e}")
            self.parser = None
    
    async def start(self):
        """Start collecting data"""
        if self.is_running:
            logger.warning(f"Collector for {self.circuit_id} is already running")
            return
        
        self.is_running = True
        self.reconnect_attempts = 0
        
        logger.info(f"Starting collector for circuit {self.circuit_id}")
        
        while self.is_running:
            try:
                await self._connect_and_collect()
                
            except Exception as e:
                logger.error(f"Collector error for {self.circuit_id}: {e}")
                await self._handle_error(str(e))
                
                if self.is_running and self.reconnect_attempts < settings.WS_MAX_RECONNECT_ATTEMPTS:
                    self.reconnect_attempts += 1
                    delay = min(settings.WS_RECONNECT_DELAY * (2 ** self.reconnect_attempts), 60)
                    logger.info(f"Reconnecting in {delay}s (attempt {self.reconnect_attempts})")
                    await asyncio.sleep(delay)
                else:
                    logger.error(f"Max reconnection attempts reached for {self.circuit_id}")
                    break
    
    async def _connect_and_collect(self):
        """Connect to WebSocket and collect data"""
        logger.info(f"Connecting to {self.websocket_url}")
        
        async with websockets.connect(self.websocket_url) as websocket:
            self.is_connected = True
            self.reconnect_attempts = 0
            await self._handle_connection_change(True)
            
            # Start heartbeat task
            heartbeat_task = asyncio.create_task(self._heartbeat(websocket))
            
            try:
                while self.is_running:
                    message = await websocket.recv()
                    await self._process_message(message)
                    
            finally:
                heartbeat_task.cancel()
                self.is_connected = False
                await self._handle_connection_change(False)
    
    async def _heartbeat(self, websocket):
        """Send periodic heartbeat to keep connection alive"""
        try:
            while self.is_running:
                await asyncio.sleep(settings.WS_HEARTBEAT_INTERVAL)
                if self.is_connected:
                    await websocket.ping()
        except Exception as e:
            logger.debug(f"Heartbeat error: {e}")
    
    async def _process_message(self, message: str):
        """Process a received message"""
        try:
            self.message_count += 1
            self.last_message_time = time.time()
            
            logger.info(f"Processing message #{self.message_count} for circuit {self.circuit_id}")
            logger.debug(f"Message preview: {message[:200]}...")
            
            # Parse message using the generated parser
            if self.parser:
                logger.info("Using generated parser")
                parsed_data = self.parser.parse_message(message)
            else:
                logger.info("No parser available, using fallback parsing")
                # Fallback: try JSON parsing
                try:
                    parsed_data = {
                        'mapped_data': {},
                        'raw_data': json.loads(message),
                        'timestamp': None
                    }
                    logger.debug("Successfully parsed as JSON")
                except:
                    # For Apex Timing, it's usually HTML/text data
                    parsed_data = {
                        'mapped_data': self._parse_apex_timing_by_teams(message),
                        'raw_data': {'raw_message': message},
                        'timestamp': None
                    }
                    logger.debug("Parsed as teams data")
            
            # Add metadata
            timing_data = {
                'circuit_id': self.circuit_id,
                'timestamp': datetime.utcnow().isoformat(),
                'mapped_data': parsed_data.get('mapped_data', {}),
                'raw_data': parsed_data.get('raw_data', {}),
                'data_type': 'live_timing',
                'source_url': self.websocket_url,
                'message_count': self.message_count
            }
            
            # Always send the first few messages, then check for changes
            should_send = (self.message_count <= 3 or self._has_data_changed(timing_data))
            
            if should_send:
                self.last_data = timing_data.copy()
                logger.info(f"Sending timing data for circuit {self.circuit_id}")
                await self._handle_data(timing_data)
            else:
                logger.debug(f"Skipping duplicate data for circuit {self.circuit_id}")
            
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            await self._handle_error(f"Message processing error: {e}")
    
    def _parse_apex_timing_message(self, message: str) -> Dict[str, Any]:
        """Parse Apex Timing HTML/text message and extract timing data"""
        mapped_data = {}
        
        try:
            # Apex Timing sends HTML table data
            # Look for table rows with timing information
            if '<tr>' in message and '<td' in message:
                # Extract position and timing data from HTML
                import re
                
                # Find table rows
                rows = re.findall(r'<tr[^>]*>(.*?)</tr>', message, re.DOTALL)
                
                for i, row in enumerate(rows[:14]):  # Limit to 14 positions (C1-C14)
                    # Extract data from table cells
                    cells = re.findall(r'<td[^>]*>(.*?)</td>', row)
                    
                    if cells and len(cells) >= 2:
                        # Try to extract meaningful data
                        position = i + 1
                        column_key = f"C{position}"
                        
                        # Extract driver name, number, time, etc.
                        driver_info = {}
                        if len(cells) > 0:
                            driver_info['position'] = position
                        if len(cells) > 1:
                            # Clean HTML tags from driver name
                            driver_name = re.sub(r'<[^>]+>', '', cells[1]).strip()
                            if driver_name:
                                driver_info['driver'] = driver_name
                        if len(cells) > 2:
                            # Try to extract timing information
                            time_str = re.sub(r'<[^>]+>', '', cells[2]).strip()
                            if time_str and ':' in time_str:
                                driver_info['time'] = time_str
                        
                        if driver_info:
                            mapped_data[column_key] = driver_info
            
            # If we couldn't parse HTML, look for key-value pairs
            elif '|' in message:
                parts = message.split('|')
                for part in parts[:14]:  # Limit to 14 entries
                    if part.strip():
                        position = len(mapped_data) + 1
                        mapped_data[f"C{position}"] = {
                            'position': position,
                            'data': part.strip()
                        }
            
            logger.debug(f"Parsed {len(mapped_data)} positions from Apex Timing data")
            
        except Exception as e:
            logger.error(f"Error parsing Apex Timing message: {e}")
        
        return mapped_data
    
    def _parse_apex_timing_by_teams(self, message: str) -> Dict[str, Any]:
        """Parse Apex Timing message and group data by team ID using circuit column mapping"""
        teams_data = {}
        
        try:
            logger.debug(f"Parsing Apex Timing message by teams: {message[:100]}...")
            
            # Parse the raw message which is typically pipe-separated
            # Example: "r141429c8|tn|26.07\nr141429c9||..."
            
            lines = message.strip().split('\n')
            
            for line in lines:
                if not line.strip():
                    continue
                    
                # Parse pipe-separated data
                parts = line.split('|')
                if len(parts) >= 1:
                    first_part = parts[0].strip()
                    
                    # Extract team ID and column from patterns like "r141429c8"
                    import re
                    match = re.match(r'r(\d+)c(\d+)', first_part)
                    if match:
                        team_id = match.group(1)
                        column_num = int(match.group(2))
                        column_key = f"c{column_num}"
                        
                        # Get the column name from circuit configuration
                        column_name = self.circuit_config.get(column_key, f"C{column_num}")
                        
                        # Initialize team data if not exists
                        if team_id not in teams_data:
                            teams_data[team_id] = {}
                        
                        # Get the value - try different positions in the pipe-separated data
                        value = None
                        for i in range(1, len(parts)):
                            potential_value = parts[i].strip()
                            if potential_value and potential_value != "":
                                value = potential_value
                                break
                        
                        # Store the value if found
                        if value:
                            teams_data[team_id][column_name] = value
                            logger.debug(f"Mapped team {team_id}, column {column_key} ({column_name}) = {value}")
            
            logger.info(f"Parsed {len(teams_data)} teams from Apex Timing data")
            
            # Return in the format expected by the frontend
            return {
                "teams_data": teams_data,
                "column_mapping": self.circuit_config
            }
            
        except Exception as e:
            logger.error(f"Error parsing Apex Timing by teams: {e}")
            # Fallback to old parsing method
            return self._parse_apex_timing_message(message)
    
    def _has_data_changed(self, new_data: Dict[str, Any]) -> bool:
        """Check if data has significantly changed since last message"""
        if not self.last_data:
            return True
        
        # Compare mapped data (ignore timestamp and message_count)
        last_mapped = self.last_data.get('mapped_data', {})
        new_mapped = new_data.get('mapped_data', {})
        
        return last_mapped != new_mapped
    
    async def _handle_data(self, data: Dict[str, Any]):
        """Handle new timing data"""
        logger.info(f"Handling data for circuit {self.circuit_id}: {len(data.get('mapped_data', {}))} mapped positions")
        
        if self.on_data_callback:
            try:
                logger.debug(f"Calling data callback for circuit {self.circuit_id}")
                await self.on_data_callback(data)
                logger.debug(f"Data callback completed for circuit {self.circuit_id}")
            except Exception as e:
                logger.error(f"Error in data callback: {e}")
        else:
            logger.warning(f"No data callback set for circuit {self.circuit_id}")
    
    async def _handle_error(self, error_message: str):
        """Handle errors"""
        if self.on_error_callback:
            try:
                await self.on_error_callback(error_message)
            except Exception as e:
                logger.error(f"Error in error callback: {e}")
    
    async def _handle_connection_change(self, connected: bool):
        """Handle connection state changes"""
        if self.on_connection_change_callback:
            try:
                await self.on_connection_change_callback(connected)
            except Exception as e:
                logger.error(f"Error in connection change callback: {e}")
    
    async def stop(self):
        """Stop collecting data"""
        logger.info(f"Stopping collector for circuit {self.circuit_id}")
        self.is_running = False
        self.is_connected = False
    
    def get_status(self) -> Dict[str, Any]:
        """Get current collector status"""
        return {
            'circuit_id': self.circuit_id,
            'is_running': self.is_running,
            'is_connected': self.is_connected,
            'reconnect_attempts': self.reconnect_attempts,
            'message_count': self.message_count,
            'last_message_time': self.last_message_time,
            'websocket_url': self.websocket_url,
            'has_parser': self.parser is not None
        }
    
    def get_last_data(self) -> Optional[Dict[str, Any]]:
        """Get the last received data"""
        return self.last_data.copy() if self.last_data else None


class CollectorManager:
    """Manages multiple collectors"""
    
    def __init__(self):
        self.collectors: Dict[str, BaseCollector] = {}
        self.tasks: Dict[str, asyncio.Task] = {}
    
    async def start_collector(self, circuit_id: str, websocket_url: str, 
                            parser_code: str = None, circuit_config: Dict[str, Any] = None) -> BaseCollector:
        """Start a collector for a circuit"""
        # Stop existing collector if running
        await self.stop_collector(circuit_id)
        
        # Create new collector
        collector = BaseCollector(circuit_id, websocket_url, parser_code, circuit_config)
        self.collectors[circuit_id] = collector
        
        # Start collector task
        task = asyncio.create_task(collector.start())
        self.tasks[circuit_id] = task
        
        logger.info(f"Started collector for circuit {circuit_id}")
        return collector
    
    async def stop_collector(self, circuit_id: str):
        """Stop a collector"""
        if circuit_id in self.collectors:
            collector = self.collectors[circuit_id]
            await collector.stop()
            
            # Cancel task
            if circuit_id in self.tasks:
                task = self.tasks[circuit_id]
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                del self.tasks[circuit_id]
            
            del self.collectors[circuit_id]
            logger.info(f"Stopped collector for circuit {circuit_id}")
    
    async def stop_all(self):
        """Stop all collectors"""
        circuit_ids = list(self.collectors.keys())
        for circuit_id in circuit_ids:
            await self.stop_collector(circuit_id)
    
    def get_collector(self, circuit_id: str) -> Optional[BaseCollector]:
        """Get a collector by circuit ID"""
        return self.collectors.get(circuit_id)
    
    def get_all_status(self) -> Dict[str, Dict[str, Any]]:
        """Get status of all collectors"""
        return {
            circuit_id: collector.get_status()
            for circuit_id, collector in self.collectors.items()
        }


# Global collector manager instance
collector_manager = CollectorManager()