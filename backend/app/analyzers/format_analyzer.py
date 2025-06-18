"""
Automatic format analyzer for WebSocket timing data
"""
import asyncio
import json
import time
import websockets
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
import structlog
from .pattern_detector import PatternDetector
from ..core.config import settings

logger = structlog.get_logger(__name__)


class FormatAnalyzer:
    """Automatically analyze WebSocket timing data format"""
    
    def __init__(self):
        self.pattern_detector = PatternDetector()
        self.samples = []
        self.message_count = 0
        self.start_time = None
        self.end_time = None
        
    async def analyze_websocket(self, websocket_url: str, circuit_mappings: Dict[str, str], 
                               duration: int = None) -> Dict[str, Any]:
        """
        Analyze a WebSocket connection to understand data format
        
        Args:
            websocket_url: WebSocket URL to analyze
            circuit_mappings: C1-C14 mappings for this circuit
            duration: Analysis duration in seconds (default from settings)
        
        Returns:
            Analysis results with detected format, patterns, and suggested mappings
        """
        duration = duration or settings.ANALYSIS_DURATION
        
        logger.info(f"Starting analysis of {websocket_url} for {duration}s")
        
        try:
            # Reset analyzer state
            self.samples = []
            self.message_count = 0
            self.start_time = time.time()
            
            # Connect and collect samples
            async with websockets.connect(websocket_url) as websocket:
                await self._collect_samples(websocket, duration)
            
            self.end_time = time.time()
            
            # Analyze collected samples
            analysis_result = await self._analyze_samples(circuit_mappings)
            analysis_result['websocket_url'] = websocket_url
            
            logger.info(f"Analysis completed: {self.message_count} messages in {self.end_time - self.start_time:.1f}s")
            
            return analysis_result
            
        except Exception as e:
            logger.error(f"Analysis failed for {websocket_url}: {e}")
            return {
                'success': False,
                'error': str(e),
                'websocket_url': websocket_url
            }
    
    async def _collect_samples(self, websocket, duration: int):
        """Collect sample messages from WebSocket"""
        timeout_time = time.time() + duration
        
        while time.time() < timeout_time:
            try:
                # Wait for message with timeout
                remaining_time = timeout_time - time.time()
                if remaining_time <= 0:
                    break
                
                message = await asyncio.wait_for(
                    websocket.recv(), 
                    timeout=min(remaining_time, 10.0)
                )
                
                self.message_count += 1
                
                # Store sample (limit to prevent memory issues)
                if len(self.samples) < settings.ANALYSIS_MIN_SAMPLES * 10:
                    self.samples.append({
                        'timestamp': time.time(),
                        'data': message,
                        'size': len(message)
                    })
                
                # Early exit if we have enough samples and some time has passed
                if (len(self.samples) >= settings.ANALYSIS_MIN_SAMPLES and 
                    time.time() - self.start_time > 10):
                    logger.info(f"Early exit with {len(self.samples)} samples")
                    break
                    
            except asyncio.TimeoutError:
                logger.warning("Timeout waiting for WebSocket message")
                continue
            except websockets.exceptions.ConnectionClosed:
                logger.warning("WebSocket connection closed during analysis")
                break
            except Exception as e:
                logger.error(f"Error collecting sample: {e}")
                continue
    
    async def _analyze_samples(self, circuit_mappings: Dict[str, str]) -> Dict[str, Any]:
        """Analyze collected samples to determine format and patterns"""
        if not self.samples:
            return {
                'success': False,
                'error': 'No samples collected',
                'samples_analyzed': 0
            }
        
        # Determine message format
        detected_format = self._detect_message_format()
        
        # Parse messages according to detected format
        parsed_samples = self._parse_samples(detected_format)
        
        # Analyze patterns in parsed data
        timing_fields = self._analyze_timing_patterns(parsed_samples)
        
        # Calculate update frequency
        update_frequency = self._calculate_update_frequency()
        
        # Generate mapping suggestions
        mapping_suggestions = self.pattern_detector.generate_mapping_suggestions(
            timing_fields, circuit_mappings
        )
        
        # Generate parser code
        parser_code = self._generate_parser_code(detected_format, timing_fields, mapping_suggestions)
        
        return {
            'success': True,
            'detected_format': detected_format,
            'samples_analyzed': len(self.samples),
            'analysis_duration': int(self.end_time - self.start_time),
            'update_frequency': update_frequency,
            'message_structure': self._get_structure_sample(parsed_samples),
            'timing_fields': timing_fields,
            'mapping_suggestions': mapping_suggestions,
            'parser_code': parser_code,
            'patterns': self._summarize_patterns(timing_fields)
        }
    
    def _detect_message_format(self) -> str:
        """Detect the format of messages (JSON, text, etc.)"""
        json_count = 0
        text_count = 0
        binary_count = 0
        
        for sample in self.samples[:50]:  # Check first 50 samples
            message = sample['data']
            
            # Try to parse as JSON
            try:
                json.loads(message)
                json_count += 1
                continue
            except:
                pass
            
            # Check if it's text (printable characters)
            try:
                if isinstance(message, bytes):
                    message.decode('utf-8')
                    binary_count += 1
                else:
                    # Check if it contains mostly printable characters
                    printable_ratio = sum(1 for c in message if c.isprintable() or c.isspace()) / len(message)
                    if printable_ratio > 0.8:
                        text_count += 1
                    else:
                        binary_count += 1
            except:
                binary_count += 1
        
        # Determine format based on majority
        if json_count > text_count and json_count > binary_count:
            return 'json'
        elif text_count > binary_count:
            return 'text'
        else:
            return 'binary'
    
    def _parse_samples(self, detected_format: str) -> List[Any]:
        """Parse samples according to detected format"""
        parsed = []
        
        for sample in self.samples:
            message = sample['data']
            
            try:
                if detected_format == 'json':
                    parsed_data = json.loads(message)
                    parsed.append(parsed_data)
                elif detected_format == 'text':
                    parsed.append({'raw_text': message})
                else:  # binary
                    parsed.append({'raw_binary': message})
                    
            except Exception as e:
                logger.warning(f"Failed to parse sample: {e}")
                continue
        
        return parsed
    
    def _analyze_timing_patterns(self, parsed_samples: List[Any]) -> Dict[str, Dict[str, Any]]:
        """Analyze timing-related patterns in parsed data"""
        return self.pattern_detector.detect_timing_fields(parsed_samples)
    
    def _calculate_update_frequency(self) -> float:
        """Calculate message update frequency"""
        if len(self.samples) < 2:
            return 0.0
        
        duration = self.end_time - self.start_time
        return self.message_count / duration if duration > 0 else 0.0
    
    def _get_structure_sample(self, parsed_samples: List[Any]) -> Dict[str, Any]:
        """Get a representative sample of the message structure"""
        if not parsed_samples:
            return {}
        
        first_sample = parsed_samples[0]
        if isinstance(first_sample, dict):
            return self.pattern_detector.analyze_json_structure(first_sample)
        else:
            return {'type': 'non_object', 'sample': str(first_sample)[:200]}
    
    def _generate_parser_code(self, detected_format: str, timing_fields: Dict[str, Dict], 
                             mapping_suggestions: Dict[str, str]) -> str:
        """Generate Python parser code for this format"""
        
        template = f'''
import json
from typing import Dict, Any, Optional

class GeneratedParser:
    """Auto-generated parser for {detected_format} timing data"""
    
    def __init__(self):
        self.format_type = "{detected_format}"
        self.field_mappings = {mapping_suggestions}
    
    def parse_message(self, message: str) -> Dict[str, Any]:
        """Parse a timing message and extract mapped data"""
        try:
'''
        
        if detected_format == 'json':
            template += '''
            data = json.loads(message)
            mapped_data = {}
            
            # Extract mapped fields
            for c_column, field_path in self.field_mappings.items():
                value = self._extract_field(data, field_path)
                if value is not None:
                    mapped_data[c_column] = value
            
            return {
                'mapped_data': mapped_data,
                'raw_data': data,
                'timestamp': self._extract_timestamp(data)
            }
'''
        elif detected_format == 'text':
            template += '''
            # Parse text format
            mapped_data = {}
            lines = message.split('\\n')
            
            # Add text parsing logic based on detected patterns
            # This would need to be customized based on actual format
            
            return {
                'mapped_data': mapped_data,
                'raw_data': {'text': message},
                'timestamp': None
            }
'''
        
        template += '''
        except Exception as e:
            return {
                'error': str(e),
                'raw_data': message
            }
    
    def _extract_field(self, data: Dict[str, Any], field_path: str) -> Any:
        """Extract a field from nested data using dot notation"""
        keys = field_path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
        
        return current
    
    def _extract_timestamp(self, data: Dict[str, Any]) -> Optional[str]:
        """Try to extract timestamp from data"""
        timestamp_fields = ['timestamp', 'time', 'ts', 'datetime']
        
        for field in timestamp_fields:
            if field in data:
                return data[field]
        
        return None
'''
        
        return template
    
    def _summarize_patterns(self, timing_fields: Dict[str, Dict]) -> Dict[str, Any]:
        """Summarize detected patterns"""
        summary = {
            'total_fields': len(timing_fields),
            'field_types': {},
            'confidence_scores': {}
        }
        
        for field_path, field_data in timing_fields.items():
            field_type = field_data.get('likely_type', 'unknown')
            score = field_data.get('score', 0)
            
            if field_type not in summary['field_types']:
                summary['field_types'][field_type] = []
            
            summary['field_types'][field_type].append(field_path)
            summary['confidence_scores'][field_path] = score
        
        return summary