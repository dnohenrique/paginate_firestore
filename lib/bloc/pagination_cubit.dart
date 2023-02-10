import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'pagination_state.dart';

class PaginationCubit extends Cubit<PaginationState> {
  PaginationCubit(
    this._query,
    this._limit,
    this._startAfterDocument, {
    this.isLive = false,
    this.includeMetadataChanges = false,
    this.options,
  }) : super(PaginationInitial());

  DocumentSnapshot? _lastDocument;
  final int _limit;
  final Query _query;
  final DocumentSnapshot? _startAfterDocument;
  final bool isLive;
  final bool includeMetadataChanges;
  final GetOptions? options;
  //final String? _searchTerm;
  final _streams = <StreamSubscription<QuerySnapshot>>[];
  var _searchTerm = '';
  var _searchSelect = [];

  void filterPaginatedList(String searchTerm, List<Object> searchSelect) {
    if (state is PaginationLoaded) {
      final loadedState = state as PaginationLoaded;
      _searchTerm = searchTerm;
      _searchSelect = searchSelect;

      final filteredList = loadedState.documentSnapshots
          .where((document) => ((searchTerm.isEmpty ||
                  document
                      .data()
                      .toString()
                      .toLowerCase()
                      .contains(searchTerm.toLowerCase())) &&
              (searchSelect.isEmpty &&
                  searchSelect.any((s) => document
                      .data()
                      .toString()
                      .toLowerCase()
                      .contains(s.toString().toLowerCase())))))
          .toList();

      emit(loadedState.copyWith(
        documentSnapshots: filteredList,
        hasReachedEnd: loadedState.hasReachedEnd,
      ));
    }
  }

  void filterQueryPaginatedList(Query newQuery) async {
    final localQuery = newQuery;
    if (isLive) {
      final listener = localQuery
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        _emitPaginatedState(querySnapshot.docs);
      });
      _streams.add(listener);
    } else {
      final querySnapshot = await localQuery.get(options);
      _emitPaginatedState(querySnapshot.docs);
    }
  }

  void refreshPaginatedList() async {
    _lastDocument = null;
    final localQuery = _getQuery();
    if (isLive) {
      final listener = localQuery
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        _emitPaginatedState(querySnapshot.docs);
      });

      _streams.add(listener);
    } else {
      final querySnapshot = await localQuery.get(options);
      _emitPaginatedState(querySnapshot.docs);
    }
  }

  void fetchPaginatedList() {
    isLive ? _getLiveDocuments() : _getDocuments();
  }

  _getDocuments() async {
    final localQuery = _getQuery();
    try {
      if (state is PaginationInitial) {
        refreshPaginatedList();
      } else if (state is PaginationLoaded) {
        final loadedState = state as PaginationLoaded;
        if (loadedState.hasReachedEnd) return;
        final querySnapshot = await localQuery.get(options);
        _emitPaginatedState(
          querySnapshot.docs,
          previousList:
              loadedState.documentSnapshots as List<QueryDocumentSnapshot>,
        );
      }
    } on PlatformException catch (exception) {
      // ignore: avoid_print
      print(exception);
      rethrow;
    }
  }

  _getLiveDocuments() {
    final localQuery = _getQuery();
    if (state is PaginationInitial) {
      refreshPaginatedList();
    } else if (state is PaginationLoaded) {
      PaginationLoaded loadedState = state as PaginationLoaded;
      if (loadedState.hasReachedEnd) return;
      final listener = localQuery
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        loadedState = state as PaginationLoaded;
        _emitPaginatedState(
          querySnapshot.docs,
          previousList:
              loadedState.documentSnapshots as List<QueryDocumentSnapshot>,
        );
      });

      _streams.add(listener);
    }
  }

  void _emitPaginatedState(
    List<QueryDocumentSnapshot> newList, {
    List<QueryDocumentSnapshot> previousList = const [],
  }) {
    _lastDocument = newList.isNotEmpty ? newList.last : null;
    emit(PaginationLoaded(
      documentSnapshots: _mergeSnapshots(previousList, newList),
      hasReachedEnd: newList.isEmpty,
    ));
  }

  List<QueryDocumentSnapshot> _mergeSnapshots(
    List<QueryDocumentSnapshot> previousList,
    List<QueryDocumentSnapshot> newList,
  ) {
    final prevIds = previousList.map((prevSnapshot) => prevSnapshot.id).toSet();
    newList.retainWhere((newSnapshot) => prevIds.add(newSnapshot.id));
    return previousList + newList;
  }

  Query _getQuery() {
    var localQuery = (_lastDocument != null)
        ? _query.startAfterDocument(_lastDocument!)
        : _startAfterDocument != null
            ? _query.startAfterDocument(_startAfterDocument!)
            : _query;
    localQuery = localQuery.limit(_limit);
    return localQuery;
  }

  void dispose() {
    for (var listener in _streams) {
      listener.cancel();
    }
  }
}
