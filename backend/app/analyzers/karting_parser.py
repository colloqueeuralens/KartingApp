"""
Karting-specific WebSocket message parser inspired by drivers.py
Uses predefined circuit mappings (C1-C14) instead of dynamic detection
"""
import json
import re
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
import structlog

logger = structlog.get_logger(__name__)

# Dictionnaire de traduction multilingue pour les colonnes
COLUMN_TRANSLATIONS = {
    # Classement/Position
    "Clt": "Classement", "Pos": "Classement", "Position": "Classement", 
    "Rk": "Classement", "Rang": "Classement", "Rank": "Classement",
    "Classement": "Classement","Pos.": "Classement",
    
    # Pilote/Driver  
    "Pilote": "Pilote", "Driver": "Pilote", "Fahrer": "Pilote", 
    "Pilota": "Pilote", "Conducente": "Pilote",
    
    # Kart/Numéro
    "Kart": "Kart", "No": "Kart", "Num": "Kart", "Number": "Kart",
    
    # Temps
    "Dernier T.": "Dernier T.", "Last": "Dernier T.", "Letzte": "Dernier T.",
    "Ultimo": "Dernier T.", "Last Time": "Dernier T.",
    
    "Meilleur T.": "Meilleur T.", "Best": "Meilleur T.", "Beste": "Meilleur T.", 
    "Migliore": "Meilleur T.", "Best Time": "Meilleur T.",
    
    # Écart
    "Ecart": "Ecart", "Gap": "Ecart", "Abstand": "Ecart", 
    "Ritardo": "Ecart", "Diferencia": "Ecart",
    
    # Tours
    "Tours": "Tours", "Laps": "Tours", "Runden": "Tours", 
    "Giri": "Tours", "Vueltas": "Tours",
    
    # Nation/Pays
    "Nation": "Nation", "Country": "Nation", "Land": "Nation",
    "Paese": "Nation", "País": "Nation",
    
    # Statut (souvent vide)
    "": "Statut",
    
    # Termes spécifiques aux essais/practice
    "Practice": "Practice", "Essai": "Practice", "Training": "Practice",
    "Session": "Session", "Time": "Time", "Temps": "Time",
    "Lap": "Tours", "Lap Time": "Dernier T.", "Tour": "Tours",
    
    # Autres termes possibles
    "Name": "Pilote", "Nom": "Pilote", "Team": "Equipe", "Équipe": "Equipe"
}


class KartingMessageParser:
    """
    Specialized parser for karting timing WebSocket messages
    Uses predefined circuit mappings for optimal precision
    Inspired by the efficient drivers.py parsing logic
    """
    
    def __init__(self, circuit_mappings: Optional[Dict[str, str]] = None):
        """
        Initialize with circuit-specific C1-C14 mappings
        
        Args:
            circuit_mappings: Dict mapping C1-C14 to field names
                            e.g., {"C1": "Classement", "C2": "Kart", "C3": "Dernier T."}
        """
        # Use provided mappings or defaults
        self.circuit_mappings = circuit_mappings or {}
        
        # Driver state cache (equivalent to drivers.py drivers global)
        self.driver_states: Dict[str, Dict[str, Any]] = {}
        
        # Raw WebSocket data storage (equivalent to drivers.py raw_data)
        self.raw_data: Dict[str, Dict[str, Tuple[str, str]]] = {}
        
        # Statistics for monitoring
        self.message_count = 0
        self.last_update = None
        
        logger.info(f"KartingParser initialized with {len(self.circuit_mappings)} column mappings")
    
    def update_circuit_mappings(self, mappings: Dict[str, str]):
        """
        Update circuit mappings when switching circuits
        
        Args:
            mappings: New C1-C14 mappings from circuit configuration
        """
        self.circuit_mappings = mappings
        logger.info(f"Updated circuit mappings: {mappings}")
        
        # Optionally trigger remapping of existing data
        if self.driver_states:
            self._remap_all_drivers()
    
    def parse_message(self, message: str) -> Dict[str, Any]:
        """
        Parse WebSocket message - supports both HTML grid and pipe formats
        
        Args:
            message: Raw WebSocket message
            
        Returns:
            Dictionary with parsed data and driver updates
        """
        self.message_count += 1
        self.last_update = datetime.now()
        
        logger.info(f"Parsing karting message #{self.message_count}")
        
        result = {
            'success': False,
            'drivers_updated': set(),
            'mapped_data': {},
            'raw_updates': {},
            'message_count': self.message_count,
            'timestamp': self.last_update.isoformat()
        }
        
        try:
            # Detect message type and parse accordingly
            if 'init' in message:
                # Parse composite initial message with HTML grid data
                raw_updates = self._parse_html_grid(message)
                logger.debug(f"Parsed composite message with HTML grid format")
            else:
                # Parse pipe format (real-time updates)
                raw_updates = self._parse_pipe_format(message)
                logger.debug(f"Parsed pipe format")
            
            if raw_updates:
                result['success'] = True
                result['drivers_updated'] = set(raw_updates.keys())
                result['raw_updates'] = raw_updates
                
                # Apply circuit mappings to get structured data
                result['mapped_data'] = self._apply_circuit_mappings(raw_updates)
                
                logger.debug(f"Successfully parsed {len(raw_updates)} driver updates")
            else:
                logger.warning("No valid karting data found in message")
                
        except Exception as e:
            logger.error(f"Error parsing message: {e}")
            result['error'] = str(e)
        
        return result
    
    def _parse_html_grid(self, message: str) -> Dict[str, Dict[str, Any]]:
        """
        Parse HTML grid format from composite initial WebSocket message
        Format: Multiple lines with one line containing grid||<tbody><tr data-id="r{driver_id}">...
        """
        updates = {}
        
        # Split message into lines and find the grid line
        lines = message.strip().split('\n')
        
        html_content = None
        
        for i, line in enumerate(lines):
            if line.startswith('grid||'):
                html_content = line[6:]  # Remove "grid||" prefix
                break
        
        if not html_content:
            logger.warning("No grid|| line found in composite message")
            return updates
        
        # Parse HTML to extract driver data
        try:
            # Import here to avoid dependency issues if not installed
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # AUTO-DÉTECTION DES COLONNES depuis l'en-tête HTML
            header_row = soup.find('tr', {'data-id': 'r0'})
            
            if header_row:
                auto_detection_success = self._extract_column_mappings_from_header(header_row)
            
            # Find all driver rows (excluding header row with data-id="r0")
            driver_rows = soup.find_all('tr', {'data-id': lambda x: x and x.startswith('r') and x != 'r0'})
            
            for row in driver_rows:
                driver_id_attr = row.get('data-id')
                if not driver_id_attr:
                    continue
                
                # Extract driver ID (remove 'r' prefix)
                driver_id = driver_id_attr[1:]  # Remove 'r' prefix
                
                # Create update entry
                updates[driver_id] = {
                    'driver_id': driver_id,
                    'raw_columns': {},
                    'timestamp': datetime.now().isoformat()
                }
                
                # Extract all column data for this driver
                cells = row.find_all('td')
                column_index = 1  # Start from C1
                
                for cell in cells:
                    # Extract cell value (text content)
                    cell_value = cell.get_text(strip=True)
                    
                    # Skip empty cells
                    if not cell_value:
                        column_index += 1
                        continue
                    
                    column_key = f"C{column_index}"
                    
                    # Store in raw_columns format
                    updates[driver_id]['raw_columns'][column_key] = {
                        'code': 'HTML',  # Mark as HTML-sourced
                        'value': cell_value,
                        'column_number': str(column_index)
                    }
                    
                    # Also store in raw_data for consistency with pipe format
                    if driver_id not in self.raw_data:
                        self.raw_data[driver_id] = {}
                    self.raw_data[driver_id][column_key] = ('HTML', cell_value)
                    
                    column_index += 1
                
                logger.debug(f"HTML Grid: Driver {driver_id} with {len(updates[driver_id]['raw_columns'])} columns")
            
            logger.info(f"Parsed HTML grid: {len(updates)} drivers with complete data")
            
        except ImportError:
            logger.error("BeautifulSoup not available for HTML parsing")
        except Exception as e:
            logger.error(f"Error parsing HTML grid: {e}")
        
        return updates
    
    def _extract_column_mappings_from_header(self, header_row) -> bool:
        """
        Extraire les mappings de colonnes depuis la ligne d'en-tête HTML (r0)
        Supporte les circuits internationaux via traduction automatique
        """
        detected_mappings = {}
        unknown_terms = []
        
        try:
            # Trouver toutes les cellules d'en-tête avec data-id="c1", "c2", etc.
            header_cells = header_row.find_all('td', {'data-id': lambda x: x and x.startswith('c')})
            
            for i, cell in enumerate(header_cells):
                column_id = cell.get('data-id')
                
                if not column_id:
                    continue
                
                # Extraire le texte de la colonne
                column_text = cell.get_text(strip=True)
                column_key = column_id.upper()  # C1, C2, etc.
                
                # Chercher une traduction dans le dictionnaire
                normalized_name = COLUMN_TRANSLATIONS.get(column_text)
                
                if normalized_name:
                    detected_mappings[column_key] = normalized_name
                    logger.debug(f"Traduit: {column_text} → {normalized_name} ({column_key})")
                else:
                    # Terme non reconnu, garder l'original et logger
                    detected_mappings[column_key] = column_text
                    unknown_terms.append(column_text)
                    logger.warning(f"Terme inconnu: {column_text} ({column_key})")
            
            # Vérifier si l'auto-détection a réussi (au moins 3 colonnes)
            if len(detected_mappings) >= 3:
                logger.info(f"Auto-détection réussie: {len(detected_mappings)} colonnes détectées")
                logger.info(f"Mappings détectés: {detected_mappings}")
                
                # Mettre à jour les mappings utilisés par le parser
                old_mappings = self.circuit_mappings.copy()
                self.circuit_mappings = detected_mappings
                
                # Logger les termes inconnus pour enrichissement futur
                if unknown_terms:
                    logger.warning(f"Termes à ajouter au dictionnaire: {unknown_terms}")
                    self._log_unknown_terms(unknown_terms)
                
                return True
            else:
                logger.warning(f"Auto-détection échouée: seulement {len(detected_mappings)} colonnes")
                return False
                
        except Exception as e:
            import traceback
            logger.error(f"Erreur lors de l'extraction des mappings: {e}")
            return False
    
    def _log_unknown_terms(self, unknown_terms: List[str]):
        """Logger les termes inconnus pour enrichissement futur du dictionnaire"""
        logger.info(f"Termes inconnus à ajouter au dictionnaire de traduction:")
        for term in unknown_terms:
            logger.info(f"   \"{term}\": \"À_TRADUIRE\",")
    
    async def _save_detected_mappings_to_firebase(self, circuit_id: str = None):
        """Sauvegarder les mappings auto-détectés dans Firebase pour réutilisation future"""
        try:
            logger.info("Firebase: Sauvegarde des mappings auto-détectés")
            
            if not circuit_id:
                logger.warning("Pas d'ID de circuit fourni - sauvegarde Firebase ignorée")
                return
            
            if not self.circuit_mappings:
                logger.warning("Pas de mappings détectés - sauvegarde Firebase ignorée")
                return
            
            # Convertir les mappings au format Firebase (C1, C2, etc.)
            firebase_mappings = {}
            for column_key, field_name in self.circuit_mappings.items():
                # column_key est déjà au format "C1", "C2", etc.
                firebase_key = column_key.lower()  # c1, c2, etc. pour Firebase
                firebase_mappings[firebase_key] = field_name
            
            # Utiliser l'intégration Firebase réelle avec await (pas d'event loop)
            try:
                from ..services.firebase_sync import firebase_sync
                
                success = await firebase_sync.update_circuit_mappings(circuit_id, firebase_mappings)
                
                if success:
                    logger.info(f"Mappings auto-détectés sauvegardés avec succès pour circuit {circuit_id}")
                else:
                    logger.error(f"Échec sauvegarde mappings auto-détectés pour circuit {circuit_id}")
                    
            except Exception as firebase_error:
                import traceback
                logger.error(f"Erreur intégration Firebase: {firebase_error}")
            
        except Exception as e:
            import traceback
            logger.error(f"Erreur sauvegarde Firebase mappings détectés: {e}")

    def _save_null_mappings_to_firebase(self, circuit_id: str = None):
        """Sauvegarder des mappings null dans Firebase pour indiquer l'échec d'auto-détection"""
        try:
            import asyncio
            
            logger.warning("Firebase: Sauvegarde des mappings null pour échec d'auto-détection")
            
            if not circuit_id:
                logger.warning("Pas d'ID de circuit fourni - sauvegarde Firebase ignorée")
                return
            
            # Utiliser l'intégration Firebase réelle
            try:
                from ..services.firebase_sync import firebase_sync
                
                # Créer une fonction async et l'exécuter
                async def save_null_mappings():
                    return await firebase_sync.save_null_mappings_to_circuit(circuit_id)
                
                # Exécuter la sauvegarde Firebase de manière synchrone
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    success = loop.run_until_complete(save_null_mappings())
                    if success:
                        logger.info(f"Mappings null sauvegardés avec succès pour circuit {circuit_id}")
                    else:
                        logger.error(f"Échec sauvegarde mappings null pour circuit {circuit_id}")
                finally:
                    loop.close()
                    
            except Exception as firebase_error:
                import traceback
                logger.error(f"Erreur intégration Firebase: {firebase_error}")
                logger.warning("Configuration manuelle nécessaire pour ce circuit")
            
        except Exception as e:
            import traceback
            logger.error(f"Erreur sauvegarde Firebase: {e}")
    
    def _parse_pipe_format(self, message: str) -> Dict[str, Dict[str, Any]]:
        """
        Parse pipe-delimited format exactly like drivers.py
        Handles: ident|code|value where ident = r{driver_id}c{column}
        """
        updates = {}
        lines = message.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Split by pipe (exactly like drivers.py)
            parts = line.split('|')
            if len(parts) != 3:
                continue
            
            ident, code, value = parts
            
            # Validate format: must start with 'r' and contain 'c'
            if not ident.startswith('r') or 'c' not in ident:
                continue
            
            try:
                # Extract driver ID and column (exactly like drivers.py)
                pilot_raw, col = ident.split('c')
                driver_id = pilot_raw[1:]  # Remove 'r' prefix
                
                # Store in raw_data structure (like drivers.py)
                if driver_id not in self.raw_data:
                    self.raw_data[driver_id] = {}
                
                column_key = f"C{col}"
                self.raw_data[driver_id][column_key] = (code, value)
                
                # Create update entry
                if driver_id not in updates:
                    updates[driver_id] = {
                        'driver_id': driver_id,
                        'raw_columns': {},
                        'timestamp': datetime.now().isoformat()
                    }
                
                updates[driver_id]['raw_columns'][column_key] = {
                    'code': code,
                    'value': value,
                    'column_number': col
                }
                
                logger.debug(f"Karting data: Driver {driver_id} -> C{col} = {value} (code: {code})")
                
            except ValueError as e:
                logger.warning(f"Malformed ident '{ident}': {e}")
                continue
        
        return updates
    
    def _apply_circuit_mappings(self, raw_updates: Dict[str, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """
        Apply circuit mappings to convert C1-C14 to meaningful field names
        Equivalent to drivers.py remap_drivers() function
        """
        mapped_data = {}
        
        for driver_id, update_data in raw_updates.items():
            mapped_driver = {
                'driver_id': driver_id,
                'timestamp': update_data['timestamp']
            }
            
            # Apply mappings for each column
            raw_columns = update_data.get('raw_columns', {})
            for column_key, column_data in raw_columns.items():
                # Get human-readable field name from mapping
                field_name = self.circuit_mappings.get(column_key, column_key)
                mapped_driver[field_name] = column_data['value']
                
                # Keep raw data for debugging
                mapped_driver[f"{column_key}_raw"] = column_data
            
            mapped_data[driver_id] = mapped_driver
        
        return mapped_data
    
    def _remap_all_drivers(self):
        """
        Remap all existing drivers with new circuit mappings
        Equivalent to drivers.py remap_drivers() when profil_colonnes changes
        """
        logger.info("Remapping all drivers with new circuit mappings")
        
        # Create new driver states using current mappings
        new_driver_states = {}
        
        for driver_id, raw_columns in self.raw_data.items():
            mapped_driver = {'driver_id': driver_id}
            
            # Apply current circuit mappings
            for column_key, (code, value) in raw_columns.items():
                field_name = self.circuit_mappings.get(column_key, column_key)
                mapped_driver[field_name] = value
                mapped_driver[f"{column_key}_raw"] = {'code': code, 'value': value}
            
            new_driver_states[driver_id] = mapped_driver
        
        self.driver_states = new_driver_states
        logger.info(f"Remapped {len(new_driver_states)} drivers")
    
    def get_driver_state(self, driver_id: str) -> Optional[Dict[str, Any]]:
        """Get current mapped state for a specific driver"""
        return self.driver_states.get(driver_id)
    
    def get_all_driver_states(self) -> Dict[str, Dict[str, Any]]:
        """Get all current mapped driver states"""
        return self.driver_states.copy()
    
    def get_raw_data(self) -> Dict[str, Dict[str, Tuple[str, str]]]:
        """Get raw WebSocket data (equivalent to drivers.py raw_data)"""
        return self.raw_data.copy()
    
    def clear_all_data(self):
        """Clear all data (useful for new sessions)"""
        self.driver_states.clear()
        self.raw_data.clear()
        self.message_count = 0
        logger.info("Cleared all karting data")
    
    def export_session_data(self) -> Dict[str, Any]:
        """
        Export current session data for persistence
        Equivalent to drivers.py save_drivers_to_file()
        """
        return {
            'driver_states': self.driver_states,
            'raw_data': self.raw_data,
            'circuit_mappings': self.circuit_mappings,
            'message_count': self.message_count,
            'last_update': self.last_update.isoformat() if self.last_update else None,
            'export_timestamp': datetime.now().isoformat()
        }
    
    def import_session_data(self, data: Dict[str, Any]):
        """
        Import session data from persistence
        """
        if 'driver_states' in data:
            self.driver_states = data['driver_states']
        if 'raw_data' in data:
            # Convert back to tuple format
            self.raw_data = {
                driver_id: {
                    col: tuple(val) if isinstance(val, list) else val 
                    for col, val in columns.items()
                }
                for driver_id, columns in data['raw_data'].items()
            }
        if 'circuit_mappings' in data:
            self.circuit_mappings = data['circuit_mappings']
        if 'message_count' in data:
            self.message_count = data['message_count']
        
        logger.info(f"Imported session data: {len(self.driver_states)} drivers, {self.message_count} messages")
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get parser statistics for monitoring"""
        return {
            'total_drivers': len(self.driver_states),
            'total_messages': self.message_count,
            'last_update': self.last_update.isoformat() if self.last_update else None,
            'circuit_mappings_count': len(self.circuit_mappings),
            'raw_data_entries': sum(len(cols) for cols in self.raw_data.values())
        }