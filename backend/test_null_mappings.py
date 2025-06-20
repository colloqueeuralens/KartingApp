#!/usr/bin/env python3
"""
Test simple pour vérifier la logique de détection des mappings null
"""

def has_null_mappings(circuit_data):
    """Version Python de la logique Flutter pour tester"""
    null_count = 0
    for i in range(1, 15):
        key = f'c{i}'
        value = circuit_data.get(key)
        if value is None or value == 'Non utilisé' or (isinstance(value, str) and value.strip() == ''):
            null_count += 1
    
    # Si moins de 3 colonnes sont configurées, considérer comme nécessitant une configuration
    configured_count = 14 - null_count
    return configured_count < 3

def test_null_mappings_detection():
    """Test de la détection des mappings null"""
    print("🧪 Test de détection des mappings null")
    
    # Circuit avec configuration complète (auto-détectée)
    circuit_complet = {
        'nom': 'Circuit Auto-Détecté',
        'c1': 'Classement',
        'c2': 'Pilote', 
        'c3': 'Kart',
        'c4': 'Dernier T.',
        'c5': 'Meilleur T.',
        'c6': 'Ecart',
        'c7': 'Tours',
        'c8': 'Non utilisé',
        'c9': 'Non utilisé',
        'c10': 'Non utilisé',
        'c11': 'Non utilisé',
        'c12': 'Non utilisé',
        'c13': 'Non utilisé',
        'c14': 'Non utilisé'
    }
    
    # Circuit avec mappings null (nécessite configuration manuelle)
    circuit_null = {
        'nom': 'Circuit International',
        'c1': None,
        'c2': None,
        'c3': None,
        'c4': None,
        'c5': None,
        'c6': None,
        'c7': None,
        'c8': None,
        'c9': None,
        'c10': None,
        'c11': None,
        'c12': None,
        'c13': None,
        'c14': None
    }
    
    # Circuit avec configuration partielle (limite)
    circuit_partiel = {
        'nom': 'Circuit Partiel',
        'c1': 'Classement',
        'c2': 'Pilote',
        'c3': 'Kart',
        'c4': 'Non utilisé',
        'c5': 'Non utilisé',
        'c6': 'Non utilisé',
        'c7': 'Non utilisé',
        'c8': 'Non utilisé',
        'c9': 'Non utilisé',
        'c10': 'Non utilisé',
        'c11': 'Non utilisé',
        'c12': 'Non utilisé',
        'c13': 'Non utilisé',
        'c14': 'Non utilisé'
    }
    
    # Circuit insuffisant (seulement 2 colonnes configurées)
    circuit_insuffisant = {
        'nom': 'Circuit Insuffisant',
        'c1': 'Classement',
        'c2': 'Pilote',
        'c3': None,
        'c4': None,
        'c5': None,
        'c6': None,
        'c7': None,
        'c8': None,
        'c9': None,
        'c10': None,
        'c11': None,
        'c12': None,
        'c13': None,
        'c14': None
    }
    
    # Tests
    test_cases = [
        (circuit_complet, False, "Circuit complet (auto-détecté)"),
        (circuit_null, True, "Circuit avec mappings null"),
        (circuit_partiel, False, "Circuit avec configuration partielle (3 colonnes)"),
        (circuit_insuffisant, True, "Circuit insuffisant (2 colonnes)"),
    ]
    
    all_passed = True
    
    for circuit_data, expected_needs_config, description in test_cases:
        result = has_null_mappings(circuit_data)
        status = "✅" if result == expected_needs_config else "❌"
        
        print(f"  {status} {description}")
        print(f"     Attendu: {'Configuration requise' if expected_needs_config else 'Prêt à utiliser'}")
        print(f"     Résultat: {'Configuration requise' if result else 'Prêt à utiliser'}")
        
        if result != expected_needs_config:
            all_passed = False
        
        # Compter les mappings null pour debug
        null_count = sum(1 for i in range(1, 15) 
                        if circuit_data.get(f'c{i}') is None 
                        or circuit_data.get(f'c{i}') == 'Non utilisé' 
                        or (isinstance(circuit_data.get(f'c{i}'), str) and circuit_data.get(f'c{i}').strip() == ''))
        print(f"     Colonnes null/vides: {null_count}/14")
        print()
    
    print(f"📊 Résumé: {'✅ Tous les tests passent' if all_passed else '❌ Certains tests échouent'}")
    return all_passed

if __name__ == "__main__":
    test_null_mappings_detection()