"""
Pattern detection for timing data
"""
import re
import json
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
import structlog

logger = structlog.get_logger(__name__)


class PatternDetector:
    """Detect patterns in timing data messages"""
    
    # Regex patterns for different data types
    TIME_PATTERNS = [
        r'\d{1,2}:\d{2}\.\d{3}',  # 1:23.456
        r'\d{1,2}:\d{2}:\d{2}\.\d{3}',  # 1:23:45.678
        r'\d+\.\d{3}',  # 123.456 (seconds only)
        r'\d{2}:\d{2}\.\d{2}',  # 01:23.45
    ]
    
    POSITION_PATTERNS = [
        r'P\d+',  # P1, P2, etc.
        r'#\d+',  # #1, #2, etc.
        r'(?:^|\s)(\d+)(?:\s|$)',  # standalone numbers
        r'Pos\s*:?\s*(\d+)',  # Pos: 1, Pos 1
    ]
    
    KART_NUMBER_PATTERNS = [
        r'(?:Kart|Car|#)\s*(\d+)',
        r'(?:^|\s)(\d{1,3})(?:\s|$)',  # 1-3 digit numbers
    ]
    
    DRIVER_PATTERNS = [
        r'[A-Z][a-z]+\s+[A-Z][a-z]+',  # First Last
        r'[A-Z]{3,}',  # ALL CAPS names
        r'[A-Z]\.\s*[A-Z][a-z]+',  # J. Smith
    ]
    
    def __init__(self):
        self.patterns = {
            'time': self.TIME_PATTERNS,
            'position': self.POSITION_PATTERNS,
            'kart_number': self.KART_NUMBER_PATTERNS,
            'driver': self.DRIVER_PATTERNS
        }
    
    def analyze_message(self, message: str) -> Dict[str, List[str]]:
        """Analyze a single message for patterns"""
        results = {}
        
        for pattern_type, patterns in self.patterns.items():
            matches = []
            for pattern in patterns:
                found = re.findall(pattern, message, re.IGNORECASE)
                if found:
                    matches.extend(found if isinstance(found[0], str) else [m[0] if isinstance(m, tuple) else str(m) for m in found])
            
            if matches:
                results[pattern_type] = list(set(matches))  # Remove duplicates
        
        return results
    
    def analyze_json_structure(self, data: Dict[str, Any], path: str = "") -> Dict[str, Any]:
        """Analyze JSON structure and detect data types"""
        structure = {}
        
        for key, value in data.items():
            current_path = f"{path}.{key}" if path else key
            
            if isinstance(value, dict):
                structure[key] = {
                    'type': 'object',
                    'structure': self.analyze_json_structure(value, current_path)
                }
            elif isinstance(value, list):
                if value:
                    first_item = value[0]
                    if isinstance(first_item, dict):
                        structure[key] = {
                            'type': 'array',
                            'item_type': 'object',
                            'structure': self.analyze_json_structure(first_item, current_path)
                        }
                    else:
                        structure[key] = {
                            'type': 'array',
                            'item_type': type(first_item).__name__
                        }
                else:
                    structure[key] = {'type': 'array', 'item_type': 'unknown'}
            else:
                # Analyze string values for patterns
                value_str = str(value)
                patterns_found = self.analyze_message(value_str)
                
                structure[key] = {
                    'type': type(value).__name__,
                    'value_sample': value_str,
                    'patterns': patterns_found
                }
        
        return structure
    
    def detect_timing_fields(self, samples: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """Detect which fields contain timing-related data"""
        field_analysis = {}
        
        for sample in samples:
            if isinstance(sample, dict):
                self._analyze_fields_recursive(sample, field_analysis)
        
        # Score fields based on pattern frequency
        scored_fields = {}
        for field_path, analysis in field_analysis.items():
            score = 0
            patterns = analysis.get('patterns', {})
            
            # Weight different pattern types
            if 'time' in patterns:
                score += len(patterns['time']) * 3
            if 'position' in patterns:
                score += len(patterns['position']) * 2
            if 'kart_number' in patterns:
                score += len(patterns['kart_number']) * 2
            if 'driver' in patterns:
                score += len(patterns['driver']) * 1
            
            if score > 0:
                scored_fields[field_path] = {
                    'score': score,
                    'patterns': patterns,
                    'likely_type': self._determine_field_type(patterns),
                    'sample_values': analysis.get('values', [])[:5]  # Keep first 5 samples
                }
        
        return scored_fields
    
    def _analyze_fields_recursive(self, data: Dict[str, Any], field_analysis: Dict[str, Dict], path: str = ""):
        """Recursively analyze fields in nested structures"""
        for key, value in data.items():
            current_path = f"{path}.{key}" if path else key
            
            if isinstance(value, dict):
                self._analyze_fields_recursive(value, field_analysis, current_path)
            elif isinstance(value, list):
                for i, item in enumerate(value[:3]):  # Analyze first 3 items
                    if isinstance(item, dict):
                        self._analyze_fields_recursive(item, field_analysis, f"{current_path}[{i}]")
                    else:
                        self._add_field_sample(field_analysis, f"{current_path}[{i}]", str(item))
            else:
                self._add_field_sample(field_analysis, current_path, str(value))
    
    def _add_field_sample(self, field_analysis: Dict, field_path: str, value: str):
        """Add a sample value to field analysis"""
        if field_path not in field_analysis:
            field_analysis[field_path] = {
                'values': [],
                'patterns': {}
            }
        
        field_analysis[field_path]['values'].append(value)
        
        # Analyze patterns in this value
        patterns = self.analyze_message(value)
        for pattern_type, matches in patterns.items():
            if pattern_type not in field_analysis[field_path]['patterns']:
                field_analysis[field_path]['patterns'][pattern_type] = []
            field_analysis[field_path]['patterns'][pattern_type].extend(matches)
    
    def _determine_field_type(self, patterns: Dict[str, List[str]]) -> str:
        """Determine the most likely field type based on patterns"""
        if 'time' in patterns:
            return 'lap_time'
        elif 'position' in patterns:
            return 'position'
        elif 'kart_number' in patterns:
            return 'kart_number'
        elif 'driver' in patterns:
            return 'driver_name'
        else:
            return 'unknown'
    
    def generate_mapping_suggestions(self, timing_fields: Dict[str, Dict], c_mappings: Dict[str, str]) -> Dict[str, str]:
        """Generate suggestions for mapping timing fields to C1-C14 columns"""
        suggestions = {}
        
        # Common mappings
        mapping_hints = {
            'classement': ['position', 'pos', 'rank'],
            'kart': ['kart', 'car', 'num', 'number'],
            'equipe/pilote': ['driver', 'pilot', 'team', 'name'],
            'dernier t.': ['time', 'lap', 'last'],
            's1': ['s1', 'sector1'],
            's2': ['s2', 'sector2'],
            's3': ['s3', 'sector3'],
            'ecart': ['gap', 'diff', 'behind'],
            'meilleur t.': ['best', 'fastest'],
            'lap': ['lap', 'laps'],
        }
        
        for c_column, c_value in c_mappings.items():
            if not c_value or c_value.lower() == 'non utilisé':
                continue
            
            c_value_lower = c_value.lower()
            best_match = None
            best_score = 0
            
            for field_path, field_data in timing_fields.items():
                score = 0
                field_path_lower = field_path.lower()
                
                # Check if field type matches expected type
                if field_data['likely_type'] == 'position' and any(hint in c_value_lower for hint in mapping_hints.get('classement', [])):
                    score += 10
                elif field_data['likely_type'] == 'kart_number' and any(hint in c_value_lower for hint in mapping_hints.get('kart', [])):
                    score += 10
                elif field_data['likely_type'] == 'driver_name' and any(hint in c_value_lower for hint in mapping_hints.get('equipe/pilote', [])):
                    score += 10
                elif field_data['likely_type'] == 'lap_time' and any(hint in c_value_lower for hint in mapping_hints.get('dernier t.', [])):
                    score += 10
                
                # Check field name similarity
                for hint_category, hints in mapping_hints.items():
                    if any(hint in c_value_lower for hint in hints):
                        if any(hint in field_path_lower for hint in hints):
                            score += 5
                
                if score > best_score:
                    best_score = score
                    best_match = field_path
            
            if best_match and best_score > 0:
                suggestions[c_column] = best_match
        
        return suggestions