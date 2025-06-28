import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Service de pagination optimisé pour Firebase avec cache et pré-chargement
class PaginationService<T> {
  final String collectionPath;
  final T Function(QueryDocumentSnapshot<Map<String, dynamic>>) fromFirestore;
  final String orderByField;
  final bool descending;
  final int pageSize;
  
  // Cache des pages
  final Map<int, List<T>> _pageCache = {};
  final Map<int, DocumentSnapshot?> _pageStartDocs = {};
  
  // État de pagination
  int _currentPage = 0;
  bool _hasNextPage = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  
  // Pré-chargement
  final bool enablePreloading;
  final int preloadPages;
  
  PaginationService({
    required this.collectionPath,
    required this.fromFirestore,
    required this.orderByField,
    this.descending = false,
    this.pageSize = 20,
    this.enablePreloading = true,
    this.preloadPages = 2,
  });
  
  /// Obtenir une page spécifique (avec cache)
  Future<List<T>> getPage(int pageNumber) async {
    // Vérifier le cache d'abord
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber]!;
    }
    
    // Si c'est la page suivante de celle actuelle, utiliser la pagination normale
    if (pageNumber == _currentPage + 1) {
      return await getNextPage();
    }
    
    // Sinon, charger la page spécifique
    return await _loadSpecificPage(pageNumber);
  }
  
  /// Obtenir la page suivante
  Future<List<T>> getNextPage() async {
    if (_isLoading || !_hasNextPage) {
      return _pageCache[_currentPage] ?? [];
    }
    
    _isLoading = true;
    
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy(orderByField, descending: descending)
          .limit(pageSize);
      
      // Si ce n'est pas la première page, utiliser startAfterDocument
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.get();
      final items = snapshot.docs.map(fromFirestore).toList();
      
      if (items.isNotEmpty) {
        _currentPage++;
        _pageCache[_currentPage] = items;
        _lastDocument = snapshot.docs.last;
        _pageStartDocs[_currentPage] = _currentPage == 1 ? null : _lastDocument;
        
        // Vérifier s'il y a une page suivante
        _hasNextPage = items.length == pageSize;
        
        // Pré-charger les pages suivantes si activé
        if (enablePreloading && _hasNextPage) {
          _preloadNextPages();
        }
      } else {
        _hasNextPage = false;
      }
      
      return items;
    } finally {
      _isLoading = false;
    }
  }
  
  /// Charger une page spécifique (pour navigation directe)
  Future<List<T>> _loadSpecificPage(int pageNumber) async {
    if (pageNumber <= 0) return [];
    
    try {
      // Calculer le nombre d'éléments à ignorer
      final skip = (pageNumber - 1) * pageSize;
      
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy(orderByField, descending: descending)
          .limit(pageSize);
      
      // Pour une page spécifique, utiliser offset (moins efficace mais nécessaire)
      if (skip > 0) {
        // Charger toutes les pages précédentes si pas en cache
        for (int i = 1; i < pageNumber; i++) {
          if (!_pageCache.containsKey(i)) {
            await _loadPageSequentially(i);
          }
        }
        
        // Utiliser le document de départ de cette page
        final startDoc = _pageStartDocs[pageNumber - 1];
        if (startDoc != null) {
          query = query.startAfterDocument(startDoc);
        }
      }
      
      final snapshot = await query.get();
      final items = snapshot.docs.map(fromFirestore).toList();
      
      _pageCache[pageNumber] = items;
      if (snapshot.docs.isNotEmpty) {
        _pageStartDocs[pageNumber] = snapshot.docs.last;
      }
      
      return items;
    } catch (e) {
      return [];
    }
  }
  
  /// Charger une page séquentiellement
  Future<void> _loadPageSequentially(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) return;
    
    final previousPage = pageNumber - 1;
    if (previousPage > 0 && !_pageCache.containsKey(previousPage)) {
      await _loadPageSequentially(previousPage);
    }
    
    await _loadSpecificPage(pageNumber);
  }
  
  /// Pré-charger les pages suivantes en arrière-plan
  void _preloadNextPages() {
    if (!enablePreloading) return;
    
    Future.microtask(() async {
      for (int i = 1; i <= preloadPages; i++) {
        final nextPageNumber = _currentPage + i;
        if (!_pageCache.containsKey(nextPageNumber) && _hasNextPage) {
          try {
            await _loadSpecificPage(nextPageNumber);
          } catch (e) {
            break; // Arrêter le pré-chargement en cas d'erreur
          }
        }
      }
    });
  }
  
  /// Réinitialiser la pagination
  void reset() {
    _pageCache.clear();
    _pageStartDocs.clear();
    _currentPage = 0;
    _hasNextPage = true;
    _lastDocument = null;
    _isLoading = false;
  }
  
  /// Invalider le cache et recharger
  Future<List<T>> refresh() async {
    reset();
    return await getNextPage();
  }
  
  /// Obtenir toutes les pages chargées
  List<T> getAllLoadedItems() {
    final allItems = <T>[];
    for (int i = 1; i <= _currentPage; i++) {
      if (_pageCache.containsKey(i)) {
        allItems.addAll(_pageCache[i]!);
      }
    }
    return allItems;
  }
  
  /// Obtenir les statistiques de pagination
  Map<String, dynamic> getStats() {
    return {
      'current_page': _currentPage,
      'cached_pages': _pageCache.length,
      'has_next_page': _hasNextPage,
      'is_loading': _isLoading,
      'total_cached_items': getAllLoadedItems().length,
      'page_size': pageSize,
    };
  }
  
  /// Obtenir une page avec fallback sur cache en cas d'erreur réseau
  Future<List<T>> getPageWithFallback(int pageNumber) async {
    try {
      return await getPage(pageNumber);
    } catch (e) {
      // En cas d'erreur, retourner la dernière page en cache si disponible
      return _pageCache[pageNumber] ?? [];
    }
  }
  
  // Getters pour l'état
  int get currentPage => _currentPage;
  bool get hasNextPage => _hasNextPage;
  bool get isLoading => _isLoading;
  bool get hasData => _pageCache.isNotEmpty;
}

/// Service de pagination spécialisé pour les tours de kart
class LapsPaginationService extends PaginationService<Map<String, dynamic>> {
  final String sessionId;
  final String kartId;
  
  LapsPaginationService({
    required this.sessionId,
    required this.kartId,
  }) : super(
    collectionPath: 'live_timing_sessions/$sessionId/laps',
    fromFirestore: (doc) => doc.data(),
    orderByField: 'lapNumber',
    descending: true, // Tours les plus récents en premier
    pageSize: 10, // Pages plus petites pour les tours
    enablePreloading: true,
    preloadPages: 1,
  );
  
  /// Requête spécialisée pour un kart spécifique
  @override
  Future<List<Map<String, dynamic>>> getNextPage() async {
    if (_isLoading || !_hasNextPage) {
      return _pageCache[_currentPage] ?? [];
    }
    
    _isLoading = true;
    
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collectionPath)
          .where('kartId', isEqualTo: kartId)
          .orderBy(orderByField, descending: descending)
          .limit(pageSize);
      
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      
      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) => doc.data()).toList();
      
      if (items.isNotEmpty) {
        _currentPage++;
        _pageCache[_currentPage] = items;
        _lastDocument = snapshot.docs.last;
        _hasNextPage = items.length == pageSize;
        
        if (enablePreloading && _hasNextPage) {
          _preloadNextPages();
        }
      } else {
        _hasNextPage = false;
      }
      
      return items;
    } finally {
      _isLoading = false;
    }
  }
}

/// Factory pour créer des services de pagination
class PaginationFactory {
  /// Créer un service de pagination pour les sessions
  static PaginationService<Map<String, dynamic>> createSessionsPagination() {
    return PaginationService<Map<String, dynamic>>(
      collectionPath: 'live_timing_sessions',
      fromFirestore: (doc) => doc.data(),
      orderByField: 'raceStart',
      descending: true,
      pageSize: 20,
    );
  }
  
  /// Créer un service de pagination pour les tours d'un kart
  static LapsPaginationService createLapsPagination(String sessionId, String kartId) {
    return LapsPaginationService(
      sessionId: sessionId,
      kartId: kartId,
    );
  }
  
  /// Créer un service de pagination générique
  static PaginationService<T> create<T>({
    required String collectionPath,
    required T Function(QueryDocumentSnapshot<Map<String, dynamic>>) fromFirestore,
    required String orderByField,
    bool descending = false,
    int pageSize = 20,
  }) {
    return PaginationService<T>(
      collectionPath: collectionPath,
      fromFirestore: fromFirestore,
      orderByField: orderByField,
      descending: descending,
      pageSize: pageSize,
    );
  }
}