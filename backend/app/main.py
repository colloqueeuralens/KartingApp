"""
FastAPI main application for karting timing backend
"""
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import Dict, Any, List, Optional
import structlog

from .core.config import settings
from .core.database import init_database, firebase_manager
from .services.firebase_sync import firebase_sync
from .services.websocket_manager import connection_manager
from .services.database_service import db_service
from .collectors.base_collector import collector_manager

logger = structlog.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting karting timing backend")
    
    # Initialize database connections
    await init_database()
    
    # Initialize Firebase
    firebase_manager.initialize()
    
    # Log WebSocket endpoint registration
    logger.info("WebSocket endpoint /circuits/{circuit_id}/live is registered")
    logger.info(f"Connection manager instance at startup: {connection_manager._instance_id}")
    
    logger.info("Backend started successfully")
    
    yield
    
    # Shutdown
    logger.info("Shutting down backend")
    
    # Stop all collectors
    await collector_manager.stop_all()
    
    logger.info("Backend shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="Karting Timing Backend",
    description="WebSocket proxy and analyzer for karting timing systems",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins in development
    allow_credentials=False,  # Must be False when using "*"
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": settings.get_current_timestamp()
    }


# Circuit management endpoints
@app.get("/circuits")
async def get_circuits() -> List[Dict[str, Any]]:
    """Get all circuits from Firebase"""
    try:
        circuits = await firebase_sync.get_all_circuits()
        return circuits
    except Exception as e:
        logger.error(f"Error fetching circuits: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch circuits")


@app.get("/circuits/{circuit_id}")
async def get_circuit(circuit_id: str) -> Dict[str, Any]:
    """Get specific circuit with mappings"""
    try:
        circuit = await firebase_sync.get_circuit_with_mappings(circuit_id)
        if not circuit:
            raise HTTPException(status_code=404, detail="Circuit not found")
        return circuit
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch circuit")


@app.get("/circuits/{circuit_id}/status")
async def get_circuit_status(circuit_id: str) -> Dict[str, Any]:
    """Get timing status for a circuit"""
    try:
        # Validate circuit exists
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        # Get collector status
        collector = collector_manager.get_collector(circuit_id)
        collector_status = collector.get_status() if collector else None
        
        # Get connection count with debug info
        connection_count = connection_manager.get_connection_count(circuit_id)
        
        # Debug connection manager state for status request
        status_debug_state = connection_manager.debug_connection_state(circuit_id)
        logger.debug(f"Connection manager state for status request: {status_debug_state}")
        
        return {
            "circuit_id": circuit_id,
            "timing_active": collector_status is not None and collector_status.get('is_connected', False),
            "collector_status": collector_status,
            "connected_clients": connection_count,
            "timestamp": settings.get_current_timestamp()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting circuit status {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get circuit status")


# Timing control endpoints
@app.post("/circuits/{circuit_id}/start-timing")
async def start_timing(circuit_id: str) -> Dict[str, Any]:
    """Start timing data collection for a circuit"""
    try:
        # Get circuit data with WebSocket URL
        circuit = await firebase_sync.get_circuit_with_mappings(circuit_id)
        if not circuit:
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        wss_url = circuit.get('wssUrl')
        if not wss_url:
            raise HTTPException(status_code=400, detail="Circuit has no WebSocket URL configured")
        
        # Check if already running
        existing_collector = collector_manager.get_collector(circuit_id)
        if existing_collector and existing_collector.get_status()['is_running']:
            return {
                "message": "Timing already active for this circuit",
                "circuit_id": circuit_id,
                "status": "already_running"
            }
        
        # Start collector with circuit configuration - no callbacks needed, raw messages go directly to karting parser
        collector = await collector_manager.start_collector(circuit_id, wss_url, circuit_config=circuit)
        
        # Simple error handler
        async def handle_error(error):
            """Handle collector errors"""
            await connection_manager.send_error(circuit_id, error)
        
        # Simple connection status handler  
        async def handle_connection_change(connected):
            """Handle connection state changes"""
            await connection_manager.send_status_update(circuit_id, {
                "timing_connected": connected,
                "timestamp": settings.get_current_timestamp()
            })
        
        collector.set_callbacks(
            on_error=handle_error,
            on_connection_change=handle_connection_change
        )
        
        logger.info(f"Started timing for circuit {circuit_id}")
        
        return {
            "message": "Timing started successfully",
            "circuit_id": circuit_id,
            "websocket_url": wss_url,
            "status": "started"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error starting timing for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to start timing")


@app.post("/circuits/{circuit_id}/stop-timing")
async def stop_timing(circuit_id: str) -> Dict[str, Any]:
    """Stop timing data collection for a circuit"""
    try:
        # Validate circuit exists
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        # Stop collector
        await collector_manager.stop_collector(circuit_id)
        
        # Notify connected clients
        await connection_manager.send_status_update(circuit_id, {
            "timing_connected": False,
            "message": "Timing stopped",
            "timestamp": settings.get_current_timestamp()
        })
        
        logger.info(f"Stopped timing for circuit {circuit_id}")
        
        return {
            "message": "Timing stopped successfully",
            "circuit_id": circuit_id,
            "status": "stopped"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error stopping timing for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to stop timing")


# Karting-specific endpoints
@app.get("/circuits/{circuit_id}/drivers")
async def get_driver_states(circuit_id: str) -> Dict[str, Any]:
    """Get current driver states with hybrid data (WebSocket + static)"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        # Get driver states from state manager
        try:
            from .services.driver_state_manager import driver_state_manager
            
            # Ensure circuit is initialized
            if driver_state_manager.current_circuit_id != circuit_id:
                success = await driver_state_manager.initialize_circuit(circuit_id)
                if not success:
                    raise HTTPException(status_code=500, detail="Failed to initialize circuit")
            
            # Get all driver states
            driver_states = driver_state_manager.get_all_driver_states()
            statistics = driver_state_manager.get_statistics()
            
            return {
                "circuit_id": circuit_id,
                "drivers": driver_states,
                "active_drivers": driver_state_manager.get_active_drivers(),
                "statistics": statistics,
                "timestamp": settings.get_current_timestamp()
            }
            
        except Exception as e:
            logger.error(f"Error getting driver states: {e}")
            raise HTTPException(status_code=500, detail="Failed to get driver states")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing driver states request: {e}")
        raise HTTPException(status_code=500, detail="Failed to process request")


@app.post("/circuits/{circuit_id}/drivers/clear")
async def clear_driver_session(circuit_id: str) -> Dict[str, Any]:
    """Clear all driver session data"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        from .services.driver_state_manager import driver_state_manager
        
        await driver_state_manager.clear_session_data()
        
        return {
            "message": "Driver session data cleared",
            "circuit_id": circuit_id,
            "timestamp": settings.get_current_timestamp()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error clearing driver session: {e}")
        raise HTTPException(status_code=500, detail="Failed to clear session")


@app.get("/circuits/{circuit_id}/session/export")
async def export_driver_session(circuit_id: str) -> Dict[str, Any]:
    """Export complete driver session data"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        from .services.driver_state_manager import driver_state_manager
        
        session_data = await driver_state_manager.export_session()
        
        return {
            "circuit_id": circuit_id,
            "session_data": session_data,
            "export_timestamp": settings.get_current_timestamp()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error exporting session: {e}")
        raise HTTPException(status_code=500, detail="Failed to export session")




# Data retrieval endpoints
@app.get("/circuits/{circuit_id}/data")
async def get_timing_data(circuit_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    """Get recent timing data for a circuit"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        data = await db_service.get_recent_timing_data(circuit_id, limit)
        return data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching timing data for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch timing data")


@app.get("/circuits/{circuit_id}/statistics")
async def get_circuit_statistics(circuit_id: str) -> Dict[str, Any]:
    """Get statistics for a circuit"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        stats = await db_service.get_circuit_statistics(circuit_id)
        return stats
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching statistics for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch statistics")


@app.get("/circuits/{circuit_id}/logs")
async def get_connection_logs(circuit_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Get connection logs for a circuit"""
    try:
        if not await firebase_sync.validate_circuit_exists(circuit_id):
            raise HTTPException(status_code=404, detail="Circuit not found")
        
        logs = await db_service.get_connection_logs(circuit_id, limit)
        return logs
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching logs for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch logs")


# Legacy analysis endpoints removed - now using direct karting parser


# WebSocket endpoint for live timing
@app.websocket("/circuits/{circuit_id}/live")
async def websocket_endpoint(websocket: WebSocket, circuit_id: str):
    """WebSocket endpoint for live timing data"""
    logger.info(f"🔥 WEBSOCKET ENDPOINT HIT 🔥 Circuit: {circuit_id}")
    logger.info(f"Connection manager instance: {connection_manager._instance_id}")
    
    try:
        logger.info(f"WebSocket connection attempt for circuit {circuit_id}")
        
        # Validate circuit exists
        circuit_exists = await firebase_sync.validate_circuit_exists(circuit_id)
        logger.info(f"Circuit {circuit_id} validation result: {circuit_exists}")
        
        if not circuit_exists:
            logger.warning(f"Circuit {circuit_id} not found in Firebase")
            await websocket.close(code=4004, reason="Circuit not found")
            return
        
        # Debug connection manager state before connecting
        pre_connect_state = connection_manager.debug_connection_state(circuit_id)
        logger.info(f"🔍 Connection manager state BEFORE connect: {pre_connect_state}")
        
        # Connect client
        logger.info(f"🔌 About to call connection_manager.connect()")
        await connection_manager.connect(websocket, circuit_id)
        logger.info(f"✅ connection_manager.connect() completed")
        
        # Debug connection manager state after connecting
        post_connect_state = connection_manager.debug_connection_state(circuit_id)
        logger.info(f"🔍 Connection manager state AFTER connect: {post_connect_state}")
        
        # Verify we have connections now
        conn_count = connection_manager.get_connection_count(circuit_id)
        logger.info(f"📊 Connection count for {circuit_id}: {conn_count}")
        
        logger.info(f"WebSocket client connected to circuit {circuit_id}")
        
        # Send connection status
        await connection_manager.send_status_update(circuit_id, {
            "timing_connected": True,
            "timestamp": settings.get_current_timestamp()
        })
        
        try:
            # Keep connection alive and handle client messages
            logger.info(f"🔄 Starting message loop for circuit {circuit_id}")
            while True:
                # Wait for client messages (ping, commands, etc.)
                try:
                    logger.debug(f"Waiting for message from client for circuit {circuit_id}")
                    message = await websocket.receive_text()
                    logger.debug(f"Received message from client: {message}")
                    
                    # Handle client commands
                    try:
                        import json
                        data = json.loads(message) if message.startswith('{') else {"type": "ping"}
                        
                        if data.get("type") == "ping":
                            logger.debug(f"Responding to ping for circuit {circuit_id}")
                            await websocket.send_json({"type": "pong", "timestamp": settings.get_current_timestamp()})
                        
                    except Exception as parse_error:
                        logger.warning(f"Error parsing message from client: {parse_error}")
                        
                except WebSocketDisconnect as disconnect_ex:
                    logger.warning(f"⚠️ WebSocket disconnect received for circuit {circuit_id}: {disconnect_ex}")
                    break
                except Exception as receive_ex:
                    logger.error(f"❌ Error receiving message for circuit {circuit_id}: {receive_ex}")
                    break
                    
        except Exception as e:
            logger.error(f"WebSocket error for circuit {circuit_id}: {e}")
            
    except Exception as e:
        logger.error(f"WebSocket connection error: {e}")
        
    finally:
        # Disconnect client
        await connection_manager.disconnect(websocket)
        
        # Debug connection manager state after disconnecting
        post_disconnect_state = connection_manager.debug_connection_state(circuit_id)
        logger.debug(f"Connection manager state after disconnect: {post_disconnect_state}")
        
        logger.info(f"WebSocket client disconnected from circuit {circuit_id}")


# Test endpoint to force a broadcast
@app.post("/circuits/{circuit_id}/test-broadcast")
async def test_broadcast(circuit_id: str) -> Dict[str, Any]:
    """Test endpoint to force a broadcast and check connections"""
    logger.info(f"🧪 TESTING BROADCAST for circuit {circuit_id}")
    
    # Check connection state before broadcast
    debug_state_before = connection_manager.debug_connection_state(circuit_id)
    logger.info(f"🔍 Connection state BEFORE test broadcast: {debug_state_before}")
    
    # Try to broadcast a test karting message (same format as real data)
    test_karting_message = "r900037777c10|in|0:18"
    
    logger.info(f"🧪 Testing with karting message: {test_karting_message}")
    
    try:
        # Test karting data processing directly
        logger.info(f"🧪 Testing karting data processing for circuit {circuit_id}")
        await connection_manager.broadcast_karting_data(circuit_id, test_karting_message)
        
        # Check connection state after broadcast
        debug_state_after = connection_manager.debug_connection_state(circuit_id)
        logger.info(f"🔍 Connection state AFTER test broadcast: {debug_state_after}")
        
        return {
            "message": "Test broadcast completed",
            "circuit_id": circuit_id,
            "connections_before": debug_state_before,
            "connections_after": debug_state_after,
            "timestamp": settings.get_current_timestamp()
        }
        
    except Exception as e:
        logger.error(f"Error in test broadcast: {e}")
        return {
            "error": str(e),
            "circuit_id": circuit_id,
            "connections": debug_state_before,
            "timestamp": settings.get_current_timestamp()
        }


# Test endpoint for composite message format
@app.post("/circuits/{circuit_id}/test-composite-message")
async def test_composite_message(circuit_id: str) -> Dict[str, Any]:
    """Test endpoint to test the new composite message format parsing"""
    logger.info(f"🧪 TESTING COMPOSITE MESSAGE for circuit {circuit_id}")
    
    # Simulate the composite message format you provided
    test_composite_message = """init|r|
best|hide|
css|no26|border-bottom-color:#00FF00 !important; color:#000000 !important;
css|no2|border-bottom-color:#16DEE9 !important; color:#000000 !important;
effects||Effecten weergeven
comments||Opmerkingen
title1||2 uurs race 
track||Kartcentrum Lelystad (735m)
grid||<tbody><tr data-id="r0" class="head" data-pos="0"><td data-id="c1" data-type="grp" data-pr="6"></td><td data-id="c2" data-type="sta" data-pr="1"></td><td data-id="c3" data-type="rk" data-pr="1">Pos.</td><td data-id="c4" data-type="no" data-pr="1">Kart</td><td data-id="c5" data-type="dr" data-pr="1">Team</td></tr><tr data-id="r900038041" data-pos="1"><td data-id="r900038041c1" class="gs"></td><td data-id="r900038041c2" class="sr"></td><td class="rk"><div><p data-id="r900038041c3" class="">1</p></div></td><td class="no"><div data-id="r900038041c4" class="no26">27</div></td><td data-id="r900038041c5" class="dr">ACE OF RACE</td></tr><tr data-id="r900038263" data-pos="8"><td data-id="r900038263c1" class="gs"></td><td data-id="r900038263c2" class="so"></td><td class="rk"><div><p data-id="r900038263c3" class="">8</p></div></td><td class="no"><div data-id="r900038263c4" class="no26">12</div></td><td data-id="r900038263c5" class="dr">FAST&CURIOUS</td></tr></tbody>
msg||test message"""
    
    logger.info(f"🧪 Testing with composite message containing grid data")
    
    try:
        # Test composite message processing directly
        logger.info(f"🧪 Testing composite message processing for circuit {circuit_id}")
        await connection_manager.broadcast_karting_data(circuit_id, test_composite_message)
        
        return {
            "message": "Composite message test completed",
            "circuit_id": circuit_id,
            "test_message_lines": len(test_composite_message.split('\n')),
            "has_grid_line": 'grid||' in test_composite_message,
            "timestamp": settings.get_current_timestamp()
        }
        
    except Exception as e:
        logger.error(f"Error in composite message test: {e}")
        return {
            "error": str(e),
            "circuit_id": circuit_id,
            "timestamp": settings.get_current_timestamp()
        }

# Debug endpoints for WebSocket connection monitoring
@app.get("/debug/connections")
async def get_debug_connections() -> Dict[str, Any]:
    """Debug endpoint to monitor WebSocket connections"""
    return {
        "instance_id": connection_manager._instance_id,
        "circuit_connections": {
            circuit_id: len(connections) 
            for circuit_id, connections in connection_manager.circuit_connections.items()
        },
        "total_connections": sum(len(conns) for conns in connection_manager.circuit_connections.values()),
        "cached_circuits": list(connection_manager.last_data_cache.keys()),
        "timestamp": settings.get_current_timestamp()
    }

@app.get("/debug/connections/{circuit_id}")
async def get_debug_circuit_connections(circuit_id: str) -> Dict[str, Any]:
    """Debug specific circuit connections"""
    normalized_id = str(circuit_id).strip()
    has_connections = normalized_id in connection_manager.circuit_connections
    connection_count = len(connection_manager.circuit_connections.get(normalized_id, set()))
    
    return {
        "instance_id": connection_manager._instance_id,
        "circuit_id": circuit_id,
        "normalized_id": normalized_id,
        "has_connections": has_connections,
        "connection_count": connection_count,
        "all_circuits": list(connection_manager.circuit_connections.keys()),
        "has_cached_data": normalized_id in connection_manager.last_data_cache,
        "timestamp": settings.get_current_timestamp()
    }

# System status endpoints
@app.get("/status")
async def get_system_status() -> Dict[str, Any]:
    """Get overall system status"""
    try:
        # Get collector statuses
        collector_statuses = collector_manager.get_all_status()
        
        # Get connection counts
        connection_counts = connection_manager.get_all_connection_counts()
        
        # Get active circuits
        active_circuits = connection_manager.get_active_circuits()
        
        # Debug overall system state
        system_debug_state = connection_manager.debug_connection_state()
        logger.debug(f"System-wide connection manager state: {system_debug_state}")
        
        return {
            "collectors": collector_statuses,
            "connections": connection_counts,
            "active_circuits": list(active_circuits),
            "total_active_circuits": len(collector_statuses),
            "total_connected_clients": sum(connection_counts.values()),
            "timestamp": settings.get_current_timestamp()
        }
        
    except Exception as e:
        logger.error(f"Error getting system status: {e}")
        raise HTTPException(status_code=500, detail="Failed to get system status")


@app.get("/debug/connections")
async def debug_connections() -> Dict[str, Any]:
    """Debug endpoint for connection manager state"""
    try:
        # Get detailed connection state
        debug_state = connection_manager.debug_connection_state()
        
        # Add collector information
        collector_statuses = collector_manager.get_all_status()
        
        return {
            "connection_manager": debug_state,
            "collectors": collector_statuses,
            "timestamp": settings.get_current_timestamp()
        }
        
    except Exception as e:
        logger.error(f"Error getting debug info: {e}")
        raise HTTPException(status_code=500, detail="Failed to get debug info")


@app.get("/debug/connections/{circuit_id}")
async def debug_circuit_connections(circuit_id: str) -> Dict[str, Any]:
    """Debug endpoint for specific circuit connections"""
    try:
        # Get detailed connection state for specific circuit
        debug_state = connection_manager.debug_connection_state(circuit_id)
        
        # Get collector status for this circuit
        collector = collector_manager.get_collector(circuit_id)
        collector_status = collector.get_status() if collector else None
        
        return {
            "circuit_id": circuit_id,
            "connection_debug": debug_state,
            "collector_status": collector_status,
            "timestamp": settings.get_current_timestamp()
        }
        
    except Exception as e:
        logger.error(f"Error getting debug info for circuit {circuit_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get debug info")


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Karting Timing Backend API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info"
    )