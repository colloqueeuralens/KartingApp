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
        """Process a received message - send directly to karting parser"""
        
        try:
            self.message_count += 1
            self.last_message_time = time.time()
            
            
            # Send raw message DIRECTLY to karting parser via websocket manager
            from ..services.websocket_manager import connection_manager
            await connection_manager.broadcast_karting_data(self.circuit_id, message)
            
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            await self._handle_error(f"Message processing error: {e}")
        
    
    # Removed all parsing methods - using karting parser directly
    
    # Removed _handle_data - no callbacks needed anymore
    
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