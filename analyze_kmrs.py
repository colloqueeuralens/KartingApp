#!/usr/bin/env python3
"""
Analyseur automatique du fichier KMRS.xlsm
Extrait structure, données, formules et logique métier
"""

import re
import json
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime

class KMRSAnalyzer:
    """Analyseur complet du fichier KMRS.xlsm"""
    
    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.analysis_result = {
            'metadata': {},
            'sheets': [],
            'formulas': {},
            'relationships': [],
            'workflow': [],
            'business_logic': {},
            'recommendations': []
        }
        
    def analyze(self) -> Dict[str, Any]:
        """Lance l'analyse complète du fichier KMRS"""
        print(f"🔍 Analyse du fichier: {self.file_path.name}")
        
        try:
            # Analyser le fichier Excel (format ZIP)
            self._analyze_excel_structure()
            self._extract_worksheets()
            self._analyze_formulas()
            self._identify_business_logic()
            self._generate_recommendations()
            
            print("✅ Analyse terminée avec succès")
            return self.analysis_result
            
        except Exception as e:
            print(f"❌ Erreur d'analyse: {e}")
            # Analyser autant que possible même en cas d'erreur
            self._fallback_analysis()
            return self.analysis_result
    
    def _analyze_excel_structure(self):
        """Analyse la structure du fichier Excel"""
        print("📊 Analyse de la structure Excel...")
        
        try:
            with zipfile.ZipFile(self.file_path, 'r') as zip_file:
                file_list = zip_file.namelist()
                
                # Métadonnées de base
                self.analysis_result['metadata'] = {
                    'filename': self.file_path.name,
                    'size_bytes': self.file_path.stat().st_size,
                    'analysis_date': datetime.now().isoformat(),
                    'excel_files': [f for f in file_list if f.endswith('.xml')],
                    'has_macros': any('vba' in f.lower() for f in file_list),
                    'total_files': len(file_list)
                }
                
                # Chercher le fichier de workbook
                workbook_files = [f for f in file_list if 'workbook' in f.lower()]
                if workbook_files:
                    self._analyze_workbook_xml(zip_file, workbook_files[0])
                
                # Chercher les feuilles
                worksheet_files = [f for f in file_list if f.startswith('xl/worksheets/')]
                self._analyze_worksheets_xml(zip_file, worksheet_files)
                
        except Exception as e:
            print(f"⚠️ Erreur structure Excel: {e}")
            self.analysis_result['metadata']['error'] = str(e)
    
    def _analyze_workbook_xml(self, zip_file: zipfile.ZipFile, workbook_path: str):
        """Analyse le fichier workbook.xml"""
        try:
            with zip_file.open(workbook_path) as workbook_file:
                content = workbook_file.read().decode('utf-8')
                
                # Extraire les noms des feuilles avec regex
                sheet_names = re.findall(r'name="([^"]+)"', content)
                self.analysis_result['metadata']['sheet_names'] = sheet_names
                self.analysis_result['metadata']['sheet_count'] = len(sheet_names)
                
                print(f"📋 Feuilles trouvées: {sheet_names}")
                
        except Exception as e:
            print(f"⚠️ Erreur workbook: {e}")
    
    def _analyze_worksheets_xml(self, zip_file: zipfile.ZipFile, worksheet_files: List[str]):
        """Analyse les fichiers de feuilles"""
        print("📄 Analyse des feuilles...")
        
        for i, worksheet_file in enumerate(worksheet_files):
            try:
                with zip_file.open(worksheet_file) as sheet_file:
                    content = sheet_file.read().decode('utf-8')
                    
                    sheet_analysis = self._analyze_worksheet_content(content, i + 1)
                    self.analysis_result['sheets'].append(sheet_analysis)
                    
            except Exception as e:
                print(f"⚠️ Erreur feuille {worksheet_file}: {e}")
    
    def _analyze_worksheet_content(self, content: str, sheet_number: int) -> Dict[str, Any]:
        """Analyse le contenu d'une feuille"""
        sheet_name = self.analysis_result['metadata'].get('sheet_names', [])[sheet_number - 1] if sheet_number <= len(self.analysis_result['metadata'].get('sheet_names', [])) else f"Sheet{sheet_number}"
        
        # Extraire les cellules avec valeurs
        cell_pattern = r'<c r="([A-Z]+\d+)"[^>]*>(?:<f[^>]*>([^<]+)</f>)?(?:<v>([^<]+)</v>)?</c>'
        cells = re.findall(cell_pattern, content)
        
        # Analyser les données
        cell_data = []
        formulas = []
        data_types = {'text': 0, 'number': 0, 'formula': 0, 'empty': 0}
        
        for cell_ref, formula, value in cells:
            cell_info = {
                'reference': cell_ref,
                'value': value if value else None,
                'formula': formula if formula else None,
                'type': 'formula' if formula else ('number' if value and value.replace('.', '').isdigit() else 'text')
            }
            cell_data.append(cell_info)
            
            if formula:
                formulas.append({'cell': cell_ref, 'formula': formula})
                data_types['formula'] += 1
            elif value:
                if value.replace('.', '').isdigit():
                    data_types['number'] += 1
                else:
                    data_types['text'] += 1
            else:
                data_types['empty'] += 1
        
        # Identifier les zones de données
        zones = self._identify_data_zones(cell_data)
        
        return {
            'name': sheet_name,
            'number': sheet_number,
            'total_cells': len(cell_data),
            'data_types': data_types,
            'formulas': formulas,
            'data_zones': zones,
            'cells': cell_data[:50],  # Limiter pour la lisibilité
            'analysis': {
                'has_formulas': len(formulas) > 0,
                'complexity': 'high' if len(formulas) > 10 else 'medium' if len(formulas) > 3 else 'low',
                'purpose': self._infer_sheet_purpose(sheet_name, formulas, cell_data)
            }
        }
    
    def _identify_data_zones(self, cell_data: List[Dict]) -> List[Dict]:
        """Identifie les zones logiques de données"""
        if not cell_data:
            return []
        
        # Grouper par proximité
        zones = []
        
        # Zone d'en-têtes (premières lignes)
        header_cells = [c for c in cell_data if int(re.search(r'\d+', c['reference']).group()) <= 3]
        if header_cells:
            zones.append({
                'type': 'headers',
                'description': 'Zone d\'en-têtes et titres',
                'cells': len(header_cells),
                'references': [c['reference'] for c in header_cells[:10]]
            })
        
        # Zone de données (lignes suivantes)
        data_cells = [c for c in cell_data if int(re.search(r'\d+', c['reference']).group()) > 3]
        if data_cells:
            zones.append({
                'type': 'data',
                'description': 'Zone de données principales',
                'cells': len(data_cells),
                'references': [c['reference'] for c in data_cells[:10]]
            })
        
        return zones
    
    def _infer_sheet_purpose(self, sheet_name: str, formulas: List, cell_data: List) -> str:
        """Infère le but de la feuille"""
        name_lower = sheet_name.lower()
        
        # Analyse par nom
        if 'config' in name_lower or 'param' in name_lower:
            return 'Configuration et paramètres'
        elif 'temps' in name_lower or 'time' in name_lower:
            return 'Analyse des temps et chronométrage'
        elif 'perform' in name_lower or 'perf' in name_lower:
            return 'Calculs de performance'
        elif 'strat' in name_lower:
            return 'Recommandations stratégiques'
        elif 'result' in name_lower or 'résult' in name_lower:
            return 'Résultats et conclusions'
        
        # Analyse par contenu
        if len(formulas) > 10:
            return 'Feuille de calculs complexes'
        elif len(formulas) > 3:
            return 'Feuille avec calculs automatiques'
        else:
            return 'Feuille de données et saisie'
    
    def _extract_worksheets(self):
        """Extraction approfondie des feuilles"""
        print("📊 Extraction des données de feuilles...")
        
        # Cette méthode peut être étendue pour une analyse plus poussée
        # en fonction de ce qui est trouvé dans la structure
        pass
    
    def _analyze_formulas(self):
        """Analyse des formules trouvées"""
        print("🧮 Analyse des formules...")
        
        all_formulas = []
        formula_types = {}
        
        for sheet in self.analysis_result['sheets']:
            for formula_info in sheet.get('formulas', []):
                formula = formula_info['formula']
                all_formulas.append(formula)
                
                # Analyser le type de formule
                if formula.startswith('SUM('):
                    formula_types['SUM'] = formula_types.get('SUM', 0) + 1
                elif formula.startswith('AVERAGE('):
                    formula_types['AVERAGE'] = formula_types.get('AVERAGE', 0) + 1
                elif formula.startswith('IF('):
                    formula_types['IF'] = formula_types.get('IF', 0) + 1
                elif formula.startswith('VLOOKUP('):
                    formula_types['VLOOKUP'] = formula_types.get('VLOOKUP', 0) + 1
                elif formula.startswith('MAX('):
                    formula_types['MAX'] = formula_types.get('MAX', 0) + 1
                elif formula.startswith('MIN('):
                    formula_types['MIN'] = formula_types.get('MIN', 0) + 1
                else:
                    formula_types['OTHER'] = formula_types.get('OTHER', 0) + 1
        
        self.analysis_result['formulas'] = {
            'total_count': len(all_formulas),
            'types': formula_types,
            'complexity': 'high' if len(all_formulas) > 50 else 'medium' if len(all_formulas) > 15 else 'low',
            'sample_formulas': all_formulas[:10]
        }
    
    def _identify_business_logic(self):
        """Identifie la logique métier"""
        print("💼 Identification de la logique métier...")
        
        business_logic = {
            'workflow_steps': [],
            'calculations': [],
            'data_flow': [],
            'user_interactions': []
        }
        
        # Analyser le workflow basé sur les feuilles
        for i, sheet in enumerate(self.analysis_result['sheets']):
            step = {
                'order': i + 1,
                'sheet': sheet['name'],
                'purpose': sheet['analysis']['purpose'],
                'complexity': sheet['analysis']['complexity'],
                'has_input': sheet['data_types']['text'] > 0,
                'has_calculations': sheet['data_types']['formula'] > 0
            }
            business_logic['workflow_steps'].append(step)
        
        # Identifier les calculs principaux
        for sheet in self.analysis_result['sheets']:
            for formula_info in sheet.get('formulas', []):
                business_logic['calculations'].append({
                    'sheet': sheet['name'],
                    'cell': formula_info['cell'],
                    'formula': formula_info['formula'],
                    'type': self._classify_calculation(formula_info['formula'])
                })
        
        self.analysis_result['business_logic'] = business_logic
    
    def _classify_calculation(self, formula: str) -> str:
        """Classifie le type de calcul"""
        if 'SUM' in formula:
            return 'Somme de valeurs'
        elif 'AVERAGE' in formula:
            return 'Calcul de moyenne'
        elif 'IF' in formula:
            return 'Logique conditionnelle'
        elif 'MAX' in formula or 'MIN' in formula:
            return 'Recherche d\'extrema'
        elif 'VLOOKUP' in formula:
            return 'Recherche de données'
        else:
            return 'Calcul personnalisé'
    
    def _generate_recommendations(self):
        """Génère des recommandations pour l'implémentation Flutter"""
        print("💡 Génération des recommandations...")
        
        recommendations = []
        
        # Recommandations basées sur la complexité
        total_formulas = self.analysis_result['formulas']['total_count']
        if total_formulas > 50:
            recommendations.append({
                'type': 'performance',
                'priority': 'high',
                'description': 'Implémenter un système de cache pour les calculs complexes',
                'reason': f'{total_formulas} formules détectées'
            })
        
        # Recommandations par type de feuille
        for sheet in self.analysis_result['sheets']:
            if 'config' in sheet['name'].lower():
                recommendations.append({
                    'type': 'ui',
                    'priority': 'medium',
                    'description': f'Créer des formulaires de configuration pour {sheet["name"]}',
                    'reason': 'Feuille de configuration identifiée'
                })
            
            if sheet['analysis']['complexity'] == 'high':
                recommendations.append({
                    'type': 'calculation',
                    'priority': 'high',
                    'description': f'Développer service de calcul spécialisé pour {sheet["name"]}',
                    'reason': f'Complexité élevée avec {len(sheet["formulas"])} formules'
                })
        
        # Recommandations générales
        recommendations.append({
            'type': 'architecture',
            'priority': 'high',
            'description': 'Utiliser les modèles StrategySheet existants et les adapter',
            'reason': 'Structure modulaire déjà en place'
        })
        
        recommendations.append({
            'type': 'ui',
            'priority': 'medium',
            'description': 'Maintenir le thème racing cohérent avec l\'app',
            'reason': 'Interface déjà développée et intégrée'
        })
        
        self.analysis_result['recommendations'] = recommendations
    
    def _fallback_analysis(self):
        """Analyse de base en cas d'erreur"""
        print("🔄 Analyse de base...")
        
        # Analyser taille et structure basique
        file_size = self.file_path.stat().st_size
        
        self.analysis_result['metadata'].update({
            'fallback_analysis': True,
            'file_size_mb': round(file_size / (1024*1024), 2),
            'estimated_complexity': 'medium' if file_size > 100000 else 'low'
        })
        
        # Créer structure de base pour 5 feuilles
        default_sheets = [
            {'name': 'Vue d\'ensemble', 'purpose': 'Configuration et paramètres généraux'},
            {'name': 'Temps', 'purpose': 'Analyse des temps de tour'},
            {'name': 'Performance', 'purpose': 'Calculs de performance'},
            {'name': 'Stratégie', 'purpose': 'Recommandations stratégiques'},
            {'name': 'Résultats', 'purpose': 'Synthèse et conclusions'}
        ]
        
        for i, sheet_info in enumerate(default_sheets):
            self.analysis_result['sheets'].append({
                'name': sheet_info['name'],
                'number': i + 1,
                'total_cells': 0,
                'analysis': {'purpose': sheet_info['purpose']},
                'estimated': True
            })
    
    def save_analysis(self, output_path: str = None):
        """Sauvegarde l'analyse en JSON"""
        if not output_path:
            output_path = f"kmrs_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(self.analysis_result, f, indent=2, ensure_ascii=False)
        
        print(f"💾 Analyse sauvegardée: {output_path}")
        return output_path
    
    def generate_flutter_specs(self) -> Dict[str, Any]:
        """Génère les spécifications pour l'implémentation Flutter"""
        print("🎯 Génération des spécifications Flutter...")
        
        flutter_specs = {
            'models': {
                'strategy_document': {
                    'sheets_count': len(self.analysis_result['sheets']),
                    'total_formulas': self.analysis_result['formulas']['total_count'],
                    'complexity_level': self.analysis_result['formulas']['complexity']
                }
            },
            'services': {
                'calculation_service': {
                    'required_functions': list(self.analysis_result['formulas']['types'].keys()),
                    'formula_count_by_type': self.analysis_result['formulas']['types']
                }
            },
            'ui_components': [],
            'implementation_priority': []
        }
        
        # Générer composants UI par feuille
        for sheet in self.analysis_result['sheets']:
            ui_component = {
                'sheet_name': sheet['name'],
                'component_type': 'StrategySheet',
                'required_widgets': [],
                'data_zones': sheet.get('data_zones', [])
            }
            
            # Déterminer les widgets nécessaires
            if sheet.get('data_types', {}).get('text', 0) > 0:
                ui_component['required_widgets'].append('TextInput')
            if sheet.get('data_types', {}).get('number', 0) > 0:
                ui_component['required_widgets'].append('NumberInput')
            if sheet.get('data_types', {}).get('formula', 0) > 0:
                ui_component['required_widgets'].append('CalculatedField')
            
            flutter_specs['ui_components'].append(ui_component)
        
        return flutter_specs


def main():
    """Fonction principale d'analyse"""
    print("🚀 ANALYSEUR KMRS.xlsm")
    print("=" * 50)
    
    # Chemin vers le fichier KMRS
    kmrs_path = "KMRS.xlsm"
    
    if not Path(kmrs_path).exists():
        print(f"❌ Fichier non trouvé: {kmrs_path}")
        return
    
    # Lancer l'analyse
    analyzer = KMRSAnalyzer(kmrs_path)
    analysis = analyzer.analyze()
    
    # Sauvegarder les résultats
    json_path = analyzer.save_analysis()
    
    # Générer les spécifications Flutter
    flutter_specs = analyzer.generate_flutter_specs()
    
    # Afficher le résumé
    print("\n" + "=" * 50)
    print("📊 RÉSUMÉ DE L'ANALYSE")
    print("=" * 50)
    
    print(f"📄 Fichier: {analysis['metadata'].get('filename', 'KMRS.xlsm')}")
    print(f"📋 Feuilles: {analysis['metadata'].get('sheet_count', len(analysis['sheets']))}")
    print(f"🧮 Formules: {analysis['formulas']['total_count']}")
    print(f"📊 Complexité: {analysis['formulas']['complexity']}")
    
    print(f"\n🔗 Feuilles détectées:")
    for sheet in analysis['sheets']:
        print(f"  • {sheet['name']}: {sheet['analysis']['purpose']}")
    
    print(f"\n💡 Recommandations: {len(analysis['recommendations'])}")
    for rec in analysis['recommendations'][:3]:
        print(f"  • {rec['description']}")
    
    print(f"\n💾 Fichiers générés:")
    print(f"  • {json_path}")
    
    return analysis, flutter_specs


if __name__ == "__main__":
    main()