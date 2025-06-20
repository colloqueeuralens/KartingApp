"""
Firebase synchronization service
"""
from typing import Dict, Any, Optional, List
from datetime import datetime
import structlog
from ..core.database import firebase_manager
try:
    from google.cloud.firestore import DatetimeWithNanoseconds
except ImportError:
    try:
        from google.cloud.firestore_v1 import DatetimeWithNanoseconds
    except ImportError:
        # Fallback for older versions
        DatetimeWithNanoseconds = None

logger = structlog.get_logger(__name__)


class FirebaseSyncService:
    """Service to sync with Firebase data from Flutter app"""
    
    def __init__(self):
        self.db = None
    
    def _serialize_firebase_data(self, data: Any) -> Any:
        """Convert Firebase data to JSON-serializable format"""
        if DatetimeWithNanoseconds and isinstance(data, DatetimeWithNanoseconds):
            return data.isoformat()
        elif isinstance(data, datetime):
            return data.isoformat()
        elif isinstance(data, dict):
            return {key: self._serialize_firebase_data(value) for key, value in data.items()}
        elif isinstance(data, list):
            return [self._serialize_firebase_data(item) for item in data]
        else:
            # Try to detect if it's a datetime-like object from Firebase
            if hasattr(data, 'isoformat') and callable(getattr(data, 'isoformat')):
                try:
                    return data.isoformat()
                except:
                    pass
            return data
    
    def _get_db(self):
        """Get Firestore database instance"""
        if not self.db:
            self.db = firebase_manager.get_db()
        return self.db
    
    async def get_circuit(self, circuit_id: str) -> Optional[Dict[str, Any]]:
        """Get circuit data from Firebase"""
        try:
            db = self._get_db()
            doc_ref = db.collection('circuits').document(circuit_id)
            doc = doc_ref.get()
            
            if doc.exists:
                data = doc.to_dict()
                data['id'] = doc.id
                return self._serialize_firebase_data(data)
            else:
                logger.warning(f"Circuit {circuit_id} not found in Firebase")
                return None
                
        except Exception as e:
            logger.error(f"Error fetching circuit {circuit_id}: {e}")
            return None
    
    async def get_all_circuits(self) -> List[Dict[str, Any]]:
        """Get all circuits from Firebase"""
        try:
            db = self._get_db()
            circuits_ref = db.collection('circuits')
            docs = circuits_ref.order_by('nom').stream()
            
            circuits = []
            for doc in docs:
                data = doc.to_dict()
                data['id'] = doc.id
                circuits.append(self._serialize_firebase_data(data))
            
            return circuits
            
        except Exception as e:
            logger.error(f"Error fetching circuits: {e}")
            return []
    
    async def get_current_session(self) -> Optional[Dict[str, Any]]:
        """Get current session data from Firebase"""
        try:
            db = self._get_db()
            doc_ref = db.collection('sessions').document('session1')
            doc = doc_ref.get()
            
            if doc.exists:
                return doc.to_dict()
            else:
                logger.warning("Session1 not found in Firebase")
                return None
                
        except Exception as e:
            logger.error(f"Error fetching session: {e}")
            return None
    
    async def get_circuit_mappings(self, circuit_id: str) -> Dict[str, str]:
        """Get C1-C14 mappings for a circuit"""
        circuit_data = await self.get_circuit(circuit_id)
        if not circuit_data:
            return {}
        
        mappings = {}
        for i in range(1, 15):  # C1 to C14
            column_key = f'c{i}'
            if column_key in circuit_data:
                mappings[column_key.upper()] = circuit_data[column_key]
        
        return mappings
    
    async def get_selected_circuit_id(self) -> Optional[str]:
        """Get the currently selected circuit ID from session"""
        session_data = await self.get_current_session()
        if session_data:
            return session_data.get('selectedCircuitId')
        return None
    
    async def get_circuit_with_mappings(self, circuit_id: str) -> Optional[Dict[str, Any]]:
        """Get circuit data with extracted mappings"""
        circuit_data = await self.get_circuit(circuit_id)
        if not circuit_data:
            return None
        
        # Extract mappings
        mappings = await self.get_circuit_mappings(circuit_id)
        
        result = {
            'id': circuit_id,
            'nom': circuit_data.get('nom'),
            'liveTimingUrl': circuit_data.get('liveTimingUrl'),
            'wssUrl': circuit_data.get('wssUrl'),
            'mappings': mappings,
            'createdAt': circuit_data.get('createdAt')
        }
        
        # Add individual column mappings (c1-c14) for collector use
        for i in range(1, 15):
            column_key = f'c{i}'
            if column_key in circuit_data:
                result[column_key] = circuit_data[column_key]
        
        # Serialize Firebase data to make it JSON-safe
        return self._serialize_firebase_data(result)
    
    async def validate_circuit_exists(self, circuit_id: str) -> bool:
        """Check if a circuit exists in Firebase"""
        circuit = await self.get_circuit(circuit_id)
        return circuit is not None
    
    async def get_active_circuits_for_timing(self) -> List[Dict[str, Any]]:
        """Get circuits that have WebSocket URLs configured"""
        circuits = await self.get_all_circuits()
        
        active_circuits = []
        for circuit in circuits:
            wss_url = circuit.get('wssUrl')
            if wss_url and wss_url.strip() and wss_url != '':
                active_circuits.append({
                    'id': circuit['id'],
                    'nom': circuit.get('nom'),
                    'wssUrl': wss_url,
                    'liveTimingUrl': circuit.get('liveTimingUrl')
                })
        
        return active_circuits
    
    async def save_null_mappings_to_circuit(self, circuit_id: str) -> bool:
        """Save null mappings to Firebase for a circuit that failed auto-detection"""
        print(f"🔥 DEBUG FIREBASE: === DÉBUT SAVE_NULL_MAPPINGS ===")
        print(f"🔥 DEBUG FIREBASE: Circuit ID: {circuit_id}")
        
        try:
            print(f"🔥 DEBUG FIREBASE: Récupération de la DB...")
            db = self._get_db()
            print(f"🔥 DEBUG FIREBASE: DB récupérée: {db is not None}")
            
            # Create null mappings for C1-C14
            null_mappings = {f'c{i}': None for i in range(1, 15)}
            print(f"🔥 DEBUG FIREBASE: Mappings null créés: {null_mappings}")
            
            # Add metadata about auto-detection failure
            update_data = {
                **null_mappings,
                'autoDetectionFailed': True,
                'autoDetectionFailedAt': datetime.now(),
                'configurationRequired': True,
                'updatedAt': datetime.now()
            }
            print(f"🔥 DEBUG FIREBASE: Data à mettre à jour: {list(update_data.keys())}")
            
            # Update the circuit document
            print(f"🔥 DEBUG FIREBASE: Mise à jour du document circuit {circuit_id}...")
            doc_ref = db.collection('circuits').document(circuit_id)
            doc_ref.update(update_data)
            print(f"🔥 DEBUG FIREBASE: Mise à jour réussie!")
            
            logger.info(f"✅ Saved null mappings to Firebase for circuit {circuit_id}")
            return True
            
        except Exception as e:
            print(f"❌ DEBUG FIREBASE: ERREUR: {e}")
            import traceback
            print(f"❌ DEBUG FIREBASE: Stack trace: {traceback.format_exc()}")
            logger.error(f"❌ Error saving null mappings to Firebase for circuit {circuit_id}: {e}")
            return False

    async def update_circuit_mappings(self, circuit_id: str, mappings: Dict[str, str]) -> bool:
        """Update circuit mappings in Firebase with auto-detected values"""
        print(f"✅ DEBUG FIREBASE: === DÉBUT UPDATE_CIRCUIT_MAPPINGS ===")
        print(f"✅ DEBUG FIREBASE: Circuit ID: {circuit_id}")
        print(f"✅ DEBUG FIREBASE: Mappings reçus: {mappings}")
        
        try:
            print(f"✅ DEBUG FIREBASE: Récupération de la DB...")
            db = self._get_db()
            print(f"✅ DEBUG FIREBASE: DB récupérée: {db is not None}")
            
            # Préparer les données de mise à jour
            update_data = {
                **mappings,  # c1, c2, c3, etc. avec leurs valeurs
                'autoDetectionSucceeded': True,
                'autoDetectionSucceededAt': datetime.now(),
                'configurationRequired': False,
                'updatedAt': datetime.now()
            }
            print(f"✅ DEBUG FIREBASE: Data à mettre à jour: {list(update_data.keys())}")
            print(f"✅ DEBUG FIREBASE: Mappings détectés: {mappings}")
            
            # Update the circuit document
            print(f"✅ DEBUG FIREBASE: Mise à jour du document circuit {circuit_id}...")
            doc_ref = db.collection('circuits').document(circuit_id)
            doc_ref.update(update_data)
            print(f"✅ DEBUG FIREBASE: Mise à jour réussie!")
            
            logger.info(f"✅ Saved auto-detected mappings to Firebase for circuit {circuit_id}")
            logger.info(f"📊 Mappings saved: {mappings}")
            return True
            
        except Exception as e:
            print(f"❌ DEBUG FIREBASE: ERREUR: {e}")
            import traceback
            print(f"❌ DEBUG FIREBASE: Stack trace: {traceback.format_exc()}")
            logger.error(f"❌ Error updating circuit mappings in Firebase for circuit {circuit_id}: {e}")
            return False


# Global service instance
firebase_sync = FirebaseSyncService()