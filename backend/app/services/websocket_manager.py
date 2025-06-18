"""
WebSocket manager for client connections
"""
import asyncio
import json
import traceback
import uuid
from typing import Dict, Set, Any, Optional
from fastapi import WebSocket
import structlog

logger = structlog.get_logger(__name__)


class ConnectionManager:
    """Manages WebSocket connections for live timing data"""
    
    def __init__(self):
        # circuit_id -> set of WebSocket connections
        self.circuit_connections: Dict[str, Set[WebSocket]] = {}
        # websocket -> circuit_id mapping for cleanup
        self.connection_circuits: Dict[WebSocket, str] = {}
        # Last data cache for each circuit
        self.last_data_cache: Dict[str, Dict[str, Any]] = {}
        # Asyncio lock for connection management (FIXED: was threading.RLock)
        self._lock = asyncio.Lock()
        # Instance ID for debugging
        self._instance_id = str(uuid.uuid4())[:8]
        logger.info(f"ConnectionManager instance created: {self._instance_id}")
        
    async def connect(self, websocket: WebSocket, circuit_id: str):
        """Connect a client to a circuit's live timing"""
        # Normalize circuit_id to handle potential string issues
        circuit_id = str(circuit_id).strip()
        logger.info(f"[{self._instance_id}] Connecting client to circuit '{circuit_id}'")
        
        try:
            await websocket.accept()
        except Exception as e:
            logger.error(f"[{self._instance_id}] Failed to accept websocket: {e}")
            return
        
        # Thread-safe connection management (FIXED: async with for asyncio.Lock)
        async with self._lock:
            # Add to circuit connections
            if circuit_id not in self.circuit_connections:
                self.circuit_connections[circuit_id] = set()
                logger.debug(f"[{self._instance_id}] Created new connection set for circuit '{circuit_id}'")
            
            self.circuit_connections[circuit_id].add(websocket)
            self.connection_circuits[websocket] = circuit_id
            
            total_connections = len(self.circuit_connections[circuit_id])
            logger.info(f"[{self._instance_id}] Client connected to circuit {circuit_id} (total: {total_connections})")
            
            # Debug: Log current state
            logger.debug(f"[{self._instance_id}] Current circuits with connections: {list(self.circuit_connections.keys())}")
        
        # Send last known data if available
        if circuit_id in self.last_data_cache:
            try:
                await websocket.send_json({
                    "type": "timing_data",
                    "data": self.last_data_cache[circuit_id]
                })
                logger.debug(f"[{self._instance_id}] Sent cached data to new client for circuit {circuit_id}")
            except Exception as e:
                logger.error(f"[{self._instance_id}] Error sending cached data to new client: {e}")
                # If we can't send cached data, disconnect the client
                await self.disconnect(websocket)
    
    async def disconnect(self, websocket: WebSocket):
        """Disconnect a client"""
        # DEBUGGING: Add stack trace to see who calls disconnect
        logger.warning(f"[{self._instance_id}] DISCONNECT CALLED")
        logger.debug(f"[{self._instance_id}] DISCONNECT STACK: {traceback.format_stack()[-3:]}")
        
        async with self._lock:  # FIXED: async with for asyncio.Lock
            circuit_id = self.connection_circuits.get(websocket)
            
            # Normalize circuit_id if it exists
            if circuit_id:
                circuit_id = str(circuit_id).strip()
            
            if circuit_id and circuit_id in self.circuit_connections:
                self.circuit_connections[circuit_id].discard(websocket)
                
                if not self.circuit_connections[circuit_id]:
                    # No more connections for this circuit
                    del self.circuit_connections[circuit_id]
                    logger.info(f"[{self._instance_id}] Last client disconnected from circuit {circuit_id}")
                else:
                    remaining = len(self.circuit_connections[circuit_id])
                    logger.info(f"[{self._instance_id}] Client disconnected from circuit {circuit_id} (remaining: {remaining})")
            
            if websocket in self.connection_circuits:
                del self.connection_circuits[websocket]
                
            # Debug: Log current state
            logger.debug(f"[{self._instance_id}] Current circuits with connections after disconnect: {list(self.circuit_connections.keys())}")
    
    async def broadcast_to_circuit(self, circuit_id: str, data: Dict[str, Any]):
        """Broadcast timing data to all clients of a circuit"""
        logger.info(f"[{self._instance_id}] Broadcasting to circuit {circuit_id}")
        
        # Small delay to ensure connection is fully established
        await asyncio.sleep(0.01)
        
        # DEBUGGING: Log state before broadcast
        state = self.debug_connection_state(circuit_id)
        logger.info(f"[{self._instance_id}] 🚨 CONNECTION STATE BEFORE BROADCAST: {state}")
        
        # Thread-safe check and copy (FIXED: async with for asyncio.Lock)
        async with self._lock:
            # Debug: Log current connection state
            logger.debug(f"[{self._instance_id}] Current circuits: {list(self.circuit_connections.keys())}")
            logger.debug(f"[{self._instance_id}] Looking for circuit: '{circuit_id}' (type: {type(circuit_id)})")
            
            # Normalize circuit_id to handle potential string issues
            circuit_id = str(circuit_id).strip()
            
            if circuit_id not in self.circuit_connections:
                logger.warning(f"[{self._instance_id}] No WebSocket connections for circuit '{circuit_id}'")
                logger.warning(f"[{self._instance_id}] Available circuits: {list(self.circuit_connections.keys())}")
                
                # Additional debugging: Check for similar circuit IDs
                similar_circuits = []
                for cid in self.circuit_connections.keys():
                    if str(cid).strip().lower() == circuit_id.lower():
                        similar_circuits.append(cid)
                
                if similar_circuits:
                    logger.error(f"[{self._instance_id}] Found similar circuits with different case/whitespace: {similar_circuits}")
                
                return
            
            # Check if the set is empty (shouldn't happen due to cleanup logic)
            if not self.circuit_connections[circuit_id]:
                logger.warning(f"[{self._instance_id}] Circuit {circuit_id} exists but has empty connection set")
                del self.circuit_connections[circuit_id]  # Clean up
                return
            
            num_connections = len(self.circuit_connections[circuit_id])
            logger.info(f"[{self._instance_id}] Broadcasting to {num_connections} clients for circuit {circuit_id}")
            
            # Create a copy of connections to avoid modification during iteration
            connections = list(self.circuit_connections[circuit_id])
        
        # Cache the data for new connections (outside the lock to avoid holding it too long)
        self.last_data_cache[circuit_id] = data
        
        # Prepare message
        message = {
            "type": "timing_data",
            "circuit_id": circuit_id,
            "data": data,
            "timestamp": data.get('timestamp')
        }
        
        disconnected = []
        sent_count = 0
        
        for websocket in connections:
            try:
                await websocket.send_json(message)
                sent_count += 1
                logger.debug(f"Successfully sent message to client {sent_count}/{num_connections}")
            except Exception as e:
                logger.warning(f"Failed to send to client: {e}")
                # FIXED: Be less aggressive about disconnecting - only disconnect on connection closed errors
                error_str = str(e).lower()
                if any(keyword in error_str for keyword in ['connection closed', 'broken pipe', 'connection reset']):
                    logger.info(f"Connection actually closed, will disconnect: {e}")
                    disconnected.append(websocket)
                else:
                    logger.warning(f"Temporary send error, keeping connection: {e}")
        
        logger.info(f"Broadcast complete: {sent_count}/{num_connections} successful, {len(disconnected)} failed")
        
        # Clean up disconnected clients
        for websocket in disconnected:
            await self.disconnect(websocket)
    
    async def send_status_update(self, circuit_id: str, status: Dict[str, Any]):
        """Send status update to clients of a circuit"""
        # Normalize circuit_id
        circuit_id = str(circuit_id).strip()
        
        async with self._lock:  # FIXED: async with for asyncio.Lock
            if circuit_id not in self.circuit_connections:
                return
            
            connections = list(self.circuit_connections[circuit_id])
        
        message = {
            "type": "status_update",
            "circuit_id": circuit_id,
            "status": status
        }
        
        disconnected = []
        
        for websocket in connections:
            try:
                await websocket.send_json(message)
            except Exception as e:
                logger.warning(f"Failed to send status to client: {e}")
                # Only disconnect on actual connection errors
                if any(keyword in str(e).lower() for keyword in ['connection closed', 'broken pipe', 'connection reset']):
                    disconnected.append(websocket)
        
        # Clean up disconnected clients
        for websocket in disconnected:
            await self.disconnect(websocket)
    
    async def send_error(self, circuit_id: str, error_message: str):
        """Send error message to clients of a circuit"""
        # Normalize circuit_id
        circuit_id = str(circuit_id).strip()
        
        async with self._lock:  # FIXED: async with for asyncio.Lock
            if circuit_id not in self.circuit_connections:
                return
            
            connections = list(self.circuit_connections[circuit_id])
        
        message = {
            "type": "error",
            "circuit_id": circuit_id,
            "error": error_message
        }
        
        disconnected = []
        
        for websocket in connections:
            try:
                await websocket.send_json(message)
            except Exception as e:
                logger.warning(f"Failed to send error to client: {e}")
                # Only disconnect on actual connection errors
                if any(keyword in str(e).lower() for keyword in ['connection closed', 'broken pipe', 'connection reset']):
                    disconnected.append(websocket)
        
        # Clean up disconnected clients
        for websocket in disconnected:
            await self.disconnect(websocket)
    
    def get_connection_count(self, circuit_id: str) -> int:
        """Get number of connected clients for a circuit"""
        # Note: This method is synchronous and should be used carefully in async context
        # Consider making it async if called from async code
        circuit_id = str(circuit_id).strip()
        
        # For now, we'll access the dict directly (not ideal but keeps compatibility)
        count = len(self.circuit_connections.get(circuit_id, set()))
        logger.debug(f"[{self._instance_id}] Connection count for circuit '{circuit_id}': {count}")
        return count
    
    def get_all_connection_counts(self) -> Dict[str, int]:
        """Get connection counts for all circuits"""
        # Note: This method is synchronous and should be used carefully in async context
        counts = {
            circuit_id: len(connections)
            for circuit_id, connections in self.circuit_connections.items()
        }
        logger.debug(f"[{self._instance_id}] All connection counts: {counts}")
        return counts
    
    def has_connections(self, circuit_id: str) -> bool:
        """Check if a circuit has any connected clients"""
        # Note: This method is synchronous and should be used carefully in async context
        circuit_id = str(circuit_id).strip()
        
        has_conn = circuit_id in self.circuit_connections and len(self.circuit_connections[circuit_id]) > 0
        logger.debug(f"[{self._instance_id}] Circuit '{circuit_id}' has connections: {has_conn}")
        return has_conn
    
    def get_active_circuits(self) -> Set[str]:
        """Get set of circuits with active connections"""
        # Note: This method is synchronous and should be used carefully in async context
        circuits = set(self.circuit_connections.keys())
        logger.debug(f"[{self._instance_id}] Active circuits: {circuits}")
        return circuits
    
    def debug_connection_state(self, circuit_id: str = None) -> Dict[str, Any]:
        """Get detailed debugging information about connection state"""
        # Note: This method is synchronous and accesses shared state
        # In production, consider making this async with proper locking
        state = {
            "instance_id": self._instance_id,
            "all_circuits": list(self.circuit_connections.keys()),
            "total_circuits": len(self.circuit_connections),
            "connection_mappings": {}
        }
        
        if circuit_id:
            # Normalize circuit_id for debugging
            circuit_id = str(circuit_id).strip()
            state["requested_circuit"] = circuit_id
            state["circuit_exists"] = circuit_id in self.circuit_connections
            state["circuit_connections"] = len(self.circuit_connections.get(circuit_id, set()))
            
            # Check for similar circuit IDs (case sensitivity, whitespace issues)
            similar_circuits = [cid for cid in self.circuit_connections.keys() if cid.strip().lower() == circuit_id.strip().lower()]
            state["similar_circuits"] = similar_circuits
        
        # Connection mapping summary
        for cid, connections in self.circuit_connections.items():
            state["connection_mappings"][cid] = {
                "count": len(connections),
                "websocket_ids": [id(ws) for ws in connections]
            }
        
        return state


# Global connection manager instance
connection_manager = ConnectionManager()