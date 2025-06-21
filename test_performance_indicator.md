# Tests Exhaustifs - Indicateur de Performance

## Vue d'ensemble
Tests pour identifier les cas où l'indicateur de performance optimal ne se met pas à jour correctement.

## Configurations de base
- **2 colonnes** : Seuil = 100% (2/2 bonnes performances)
- **3 colonnes** : Seuil = 66% (2/3 bonnes performances) 
- **4 colonnes** : Seuil = 75% (3/4 bonnes performances)

## Tests par Catégorie

### 1. Tests de Création Progressive

#### Test 1.1 - Configuration 3 colonnes vides  --- OK
1. **État initial** : [vide, vide, vide]
   - Attendu : 0%, "ATTENDRE..."
2. **Ajouter kart1++ en col1** : [kart1++, vide, vide]
   - Attendu : 33%, "ATTENDRE..."
3. **Ajouter kart2+ en col2** : [kart1++, kart2+, vide]
   - Attendu : 66%, "C'EST LE MOMENT !"
4. **Ajouter kart3~ en col3** : [kart1++, kart2+, kart3~]
   - Attendu : 66%, "C'EST LE MOMENT !"


#### Test 1.2 - Configuration 2 colonnes (seuil 100%) --- OK
1. **État initial** : [vide, vide]
   - Attendu : 0%, "ATTENDRE..."
2. **Ajouter kart1++ en col1** : [kart1++, vide]
   - Attendu : 50%, "ATTENDRE..."
3. **Ajouter kart2+ en col2** : [kart1++, kart2+]
   - Attendu : 100%, "C'EST LE MOMENT !"



### 2. Tests de Modification de Performance

#### Test 2.1 - Changement de performance première position
État initial : [kart1++, kart2+, kart3~] = 66% "C'EST LE MOMENT !"

1. **Modifier kart1++ → kart1-** : [kart1-, kart2+, kart3~]
   - Attendu : 33%, "ATTENDRE..."
2. **Modifier kart1- → kart1++** : [kart1++, kart2+, kart3~]
   - Attendu : 66%, "C'EST LE MOMENT !"
3. **Modifier kart2+ → kart2--** : [kart1++, kart2--, kart3~]
   - Attendu : 33%, "ATTENDRE..."

#### Test 2.2 - Changement de performance deuxième position (ne doit pas affecter)
État initial : [kart1++ + kart5~, kart2+, kart3~] = 66% "C'EST LE MOMENT !"

1. **Modifier kart5~ → kart5++** : [kart1++ + kart5++, kart2+, kart3~]
   - Attendu : 66%, "C'EST LE MOMENT !" (inchangé car kart5 n'est pas premier)

### 3. Tests de Suppression

#### Test 3.1 - Suppression première position
État initial : [kart1++, kart2+, kart3~] = 66% "C'EST LE MOMENT !"

1. **Supprimer kart1++** : [vide, kart2+, kart3~]
   - Attendu : 33%, "ATTENDRE..."

#### Test 3.2 - Suppression avec promotion
État initial : [kart1++ + kart5-, kart2+, kart3~] = 66% "C'EST LE MOMENT !"

1. **Supprimer kart1++** : [kart5-, kart2+, kart3~]
   - Attendu : 33%, "ATTENDRE..." (kart5- devient premier)

### 4. Tests de Drag & Drop

#### Test 4.1 - Déplacement simple
État initial : [kart1++, kart2+, vide] = 66% "C'EST LE MOMENT !"

1. **Déplacer kart1++ de col1 vers col3** : [vide, kart2+, kart1++]
   - Attendu : 66%, "C'EST LE MOMENT !"

#### Test 4.2 - Déplacement avec changement de position
État initial : [kart1++ + kart5-, kart2+, vide] = 66% "C'EST LE MOMENT !"

1. **Déplacer kart1++ de col1 vers col3** : [kart5-, kart2+, kart1++]
   - Attendu : 66%, "C'EST LE MOMENT !" (kart5- devient premier en col1, kart1++ devient premier en col3)

### 5. Tests de Cas Limites

#### Test 5.1 - Configuration 4 colonnes (seuil 75%)
1. **État** : [kart1++, kart2+, kart3+, vide] = 75% "C'EST LE MOMENT !"
2. **Ajouter kart4-** : [kart1++, kart2+, kart3+, kart4-] = 75% "C'EST LE MOMENT !"
3. **Modifier kart3+ → kart3-** : [kart1++, kart2+, kart3-, kart4-] = 50% "ATTENDRE..."

#### Test 5.2 - Vidage complet
État initial : [kart1++, kart2+, kart3~] = 66% "C'EST LE MOMENT !"

1. **Supprimer tous les karts** : [vide, vide, vide]
   - Attendu : 0%, "ATTENDRE..."

#### Test 5.3 - Performances identiques
1. **État** : [kart1++, kart2++, kart3++] = 100% "C'EST LE MOMENT !"
2. **État** : [kart1--, kart2--, kart3--] = 0% "ATTENDRE..."

### 6. Tests de Performance Rapide

#### Test 6.1 - Actions successives rapides
1. Créer kart1++ en col1
2. Immédiatement créer kart2+ en col2
3. Immédiatement modifier kart1++ → kart1-
4. Immédiatement supprimer kart1-
5. Vérifier que l'indicateur suit chaque changement

#### Test 6.2 - Drag & drop multiples
1. Créer plusieurs karts
2. Effectuer plusieurs drag & drop rapidement
3. Vérifier que l'indicateur reste cohérent

## Instructions de Test

1. **Effectuer chaque test manuellement**
2. **Noter les cas où l'indicateur ne se met pas à jour**
3. **Identifier les patterns de dysfonctionnement**
4. **Documenter l'état attendu vs observé**

## Logs de Debug à Ajouter

```dart
print('=== DEBUG PERFORMANCE ===');
print('ColsData length: ${colsData.length}');
print('Good count: $good');
print('Current kart count: $currentKartCount');
print('Calculated %: $calculatedPct');
print('Threshold: $threshold');
print('Is transitional: $isTransitionalState');
print('Final %: $pct, Optimal: $isOpt');
print('========================');
```

## Résultats Attendus

Après ces tests, nous devrons identifier :
- Quels cas ne se mettent pas à jour
- Si c'est un problème de logique ou de timing
- Corrections spécifiques à apporter