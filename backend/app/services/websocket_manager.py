"""
WebSocket manager for client connections with karting data processing
"""
import asyncio
import json
import traceback
import uuid
from typing import Dict, Set, Any, Optional
from fastapi import WebSocket
import structlog

# Removed driver_state_manager import - using direct karting parser
# from ..models.karting_data import WebSocketMessage, KartingStatistics

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
        
        # Thread-safe connection management
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
        
        # Send cached data if available
        try:
            if circuit_id in self.last_data_cache:
                await websocket.send_json({
                    "type": "cached_data",
                    "data": self.last_data_cache[circuit_id]
                })
                logger.debug(f"[{self._instance_id}] Sent cached data to new client for circuit {circuit_id}")
        except Exception as e:
            logger.error(f"[{self._instance_id}] Error sending cached data to new client: {e}")
    
    # Removed _ensure_circuit_initialized - no longer needed with direct parser
    
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
    
    async def broadcast_karting_data(self, circuit_id: str, raw_message: str):
        """
        SIMPLIFIED: Process raw message directly through karting parser and broadcast
        Direct WebSocket → KartingParser → Clients flow
        """
        print(f"🎯 DEBUG WEBSOCKET: === DÉBUT BROADCAST_KARTING_DATA ===")
        print(f"🎯 DEBUG WEBSOCKET: Circuit ID: {circuit_id}")
        print(f"🎯 DEBUG WEBSOCKET: Type de message: {type(raw_message)}")
        print(f"🎯 DEBUG WEBSOCKET: Longueur message: {len(raw_message) if raw_message else 0}")
        print(f"🎯 DEBUG WEBSOCKET: Contient 'grid||': {'grid||' in raw_message if raw_message else False}")
        print(f"🎯 DEBUG WEBSOCKET: Message (premiers 200 chars): {raw_message[:200] if raw_message else 'None'}...")
        
        logger.info(f"🎯 WEBSOCKET MANAGER: DIRECT KARTING PROCESSING for circuit {circuit_id}")
        logger.info(f"🚨 DEBUG VERSION 2.0 - PROCESSING MESSAGE")
        logger.info(f"🔍 WEBSOCKET MANAGER: Message type: {type(raw_message)}")
        logger.info(f"🔍 WEBSOCKET MANAGER: Message length: {len(raw_message) if raw_message else 0}")
        logger.info(f"📝 WEBSOCKET MANAGER: Raw message (first 100 chars): {raw_message[:100]}...")
        
        try:
            # Import karting parser directly
            from ..analyzers.karting_parser import KartingMessageParser
            
            # Create parser instance with circuit mappings if available
            try:
                from ..services.firebase_sync import firebase_sync
                circuit = await firebase_sync.get_circuit_with_mappings(circuit_id)
                mappings = circuit.get('mappings', {}) if circuit else {}
            except Exception as e:
                logger.warning(f"Could not get circuit mappings: {e}")
                mappings = {}
            
            parser = KartingMessageParser(mappings)
            
            # Parse the raw message directly
            result = parser.parse_message(raw_message)
            
            if not result.get('success'):
                print(f"❌ DEBUG WEBSOCKET: Parser failed: {result.get('error', 'Unknown error')}")
                logger.warning(f"❌ Parser failed: {result.get('error', 'Unknown error')}")
                
                # Si l'auto-détection a échoué, sauvegarder des mappings null dans Firebase
                if 'grid||' in raw_message:  # C'est un message initial d'auto-détection
                    print(f"🔥 DEBUG WEBSOCKET: Message grid|| détecté, échec auto-détection pour circuit {circuit_id}")
                    try:
                        from ..services.firebase_sync import firebase_sync
                        from ..analyzers.karting_parser import KartingMessageParser
                        
                        print(f"🔥 DEBUG WEBSOCKET: Création parser temporaire pour sauvegarde Firebase...")
                        # Créer temporairement un parser pour accéder à la méthode
                        temp_parser = KartingMessageParser()
                        temp_parser._save_null_mappings_to_firebase(circuit_id)
                        
                        print(f"⚙️ DEBUG WEBSOCKET: Circuit {circuit_id} marqué comme nécessitant une configuration manuelle")
                        logger.warning(f"⚙️ Circuit {circuit_id} marqué comme nécessitant une configuration manuelle")
                        
                    except Exception as save_error:
                        print(f"❌ DEBUG WEBSOCKET: Erreur sauvegarde mappings null: {save_error}")
                        logger.error(f"❌ Erreur sauvegarde mappings null: {save_error}")
                else:
                    print(f"🔍 DEBUG WEBSOCKET: Message non-grid, pas de sauvegarde Firebase")
                
                return
            
            print(f"✅ DEBUG WEBSOCKET: Parser success: {len(result.get('drivers_updated', []))} drivers updated")
            logger.info(f"✅ WEBSOCKET MANAGER: Parser success: {len(result.get('drivers_updated', []))} drivers updated")
            
            # Si c'est un message grid|| ou init, vérifier si l'auto-détection a fonctionné
            if 'grid||' in raw_message or 'init' in raw_message:
                print(f"🎯 DEBUG WEBSOCKET: Message initial avec succès pour circuit {circuit_id}")
                print(f"🎯 DEBUG WEBSOCKET: Mappings du parser après parsing: {parser.circuit_mappings}")
                
                # NOUVEAU: Sauvegarder les mappings auto-détectés dans Firebase
                if parser.circuit_mappings and len(parser.circuit_mappings) >= 3:
                    print(f"🎉 DEBUG WEBSOCKET: Auto-détection réussie! Sauvegarde des mappings dans Firebase...")
                    try:
                        await parser._save_detected_mappings_to_firebase(circuit_id)
                        print(f"✅ DEBUG WEBSOCKET: Sauvegarde mappings auto-détectés terminée")
                    except Exception as save_error:
                        print(f"❌ DEBUG WEBSOCKET: Erreur sauvegarde mappings auto-détectés: {save_error}")
                        logger.error(f"❌ Erreur sauvegarde mappings auto-détectés: {save_error}")
                else:
                    print(f"⚠️ DEBUG WEBSOCKET: Pas assez de mappings détectés pour sauvegarder: {len(parser.circuit_mappings) if parser.circuit_mappings else 0}")
            
            # Create simple JSON message in desired format: {"driver_id": {"field": "value"}}
            simple_drivers = {}
            mapped_data = result.get('mapped_data', {})
            
            logger.info(f"🔍 DEBUG: mapped_data = {mapped_data}")
            
            for driver_id, driver_data in mapped_data.items():
                # Clean up driver data to only include field:value pairs
                simple_driver = {}
                for key, value in driver_data.items():
                    if not key.endswith('_raw') and key not in ['driver_id', 'timestamp']:
                        simple_driver[key] = value
                simple_drivers[driver_id] = simple_driver
                logger.info(f"🔍 DEBUG: driver {driver_id} -> {simple_driver}")
            
            # Broadcast simple format
            message = {
                "type": "karting_data",
                "circuit_id": circuit_id,
                "drivers": simple_drivers,
                "message_count": result.get('message_count', 0),
                "timestamp": result.get('timestamp')
            }
            
            logger.info(f"📊 COMPLETE MESSAGE TO SEND: {message}")
            
            await self._broadcast_message_to_circuit(circuit_id, message)
            
            # NOUVEAU: Log détaillé de l'état complet de tous les karts après traitement
            print(f"")
            print(f"🏁 ====== BACKEND - ÉTAT COMPLET APRÈS TRAITEMENT MESSAGE ======")
            print(f"📊 Circuit: {circuit_id}")
            print(f"📊 Total karts traités dans ce message: {len(simple_drivers)}")
            print(f"")
            
            # Trier les karts par ID pour un affichage ordonné
            sorted_drivers = sorted(simple_drivers.items(), key=lambda x: x[0])
            
            for driver_id, driver_data in sorted_drivers:
                print(f"🏎️  BACKEND KART #{driver_id}:")
                # Trier les champs par nom pour un affichage cohérent
                sorted_fields = sorted(driver_data.items(), key=lambda x: x[0])
                for field_name, field_value in sorted_fields:
                    print(f"    • {field_name} → {field_value}")
                print(f"")
            
            print(f"🏁 ====== FIN ÉTAT BACKEND ======")
            print(f"")
            
            # Log the actual drivers data that was sent
            logger.info(f"📊 DRIVERS DATA SENT: {simple_drivers}")
            logger.info(f"🎯 WEBSOCKET MANAGER: Successfully broadcast {len(simple_drivers)} drivers")
            
        except Exception as e:
            logger.error(f"❌ Error in direct karting processing: {e}")
            # Send error to clients
            await self.send_error(circuit_id, f"Error processing timing data: {str(e)}")

    async def broadcast_to_circuit(self, circuit_id: str, data: Any):
        """
        REMOVED: This method is no longer needed - use broadcast_karting_data directly
        """
        logger.warning(f"⚠️ broadcast_to_circuit called but is deprecated. Use broadcast_karting_data directly.")
        logger.info(f"🔧 Converting call to broadcast_karting_data for circuit {circuit_id}")
        
        # Convert to string and route to direct processor
        if isinstance(data, str):
            message_str = data
        else:
            message_str = str(data) if data else ""
        
        await self.broadcast_karting_data(circuit_id, message_str)

    async def _broadcast_message_to_circuit(self, circuit_id: str, message_data: Dict[str, Any]):
        """Internal method to broadcast a message to circuit clients"""
        logger.info(f"[{self._instance_id}] Broadcasting to circuit {circuit_id}")
        
        # Small delay to ensure connection is fully established
        await asyncio.sleep(0.01)
        
        # Thread-safe check and copy
        async with self._lock:
            # Normalize circuit_id to handle potential string issues
            circuit_id = str(circuit_id).strip()
            
            if circuit_id not in self.circuit_connections:
                logger.warning(f"[{self._instance_id}] No WebSocket connections for circuit '{circuit_id}'")
                return
            
            # Check if the set is empty
            if not self.circuit_connections[circuit_id]:
                logger.warning(f"[{self._instance_id}] Circuit {circuit_id} exists but has empty connection set")
                del self.circuit_connections[circuit_id]  # Clean up
                return
            
            num_connections = len(self.circuit_connections[circuit_id])
            logger.info(f"[{self._instance_id}] Broadcasting to {num_connections} clients for circuit {circuit_id}")
            
            # Create a copy of connections to avoid modification during iteration
            connections = list(self.circuit_connections[circuit_id])
        
        # Cache the data for new connections
        self.last_data_cache[circuit_id] = message_data
        
        # Prepare message with metadata
        message = {
            "type": message_data.get("type", "timing_data"),
            "circuit_id": circuit_id,
            "data": message_data,
            "timestamp": message_data.get('timestamp')
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
                # Be less aggressive about disconnecting - only disconnect on connection closed errors
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