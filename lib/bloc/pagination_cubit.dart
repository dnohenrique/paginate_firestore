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

  final int _limit;
  final Query _query;
  final DocumentSnapshot? _startAfterDocument;
  final bool isLive;
  final bool includeMetadataChanges;
  final GetOptions? options;
  //final String? _searchTerm;
  final _streams = <StreamSubscription<List<QueryDocumentSnapshot>>>[];
  String _searchTerm = '';
  List<Object> _searchSelect = [];
  List<QueryDocumentSnapshot> listAll = [];
  List<QueryDocumentSnapshot> listView = [];
  int pageNumber = 1;
  int limit = 10;

  void filterPaginatedList(String searchTerm, List<Object> searchSelect) {
    // if (state is PaginationLoaded) {
    //   final loadedState = state as PaginationLoaded;
    _searchTerm = searchTerm;
    _searchSelect = searchSelect;

    pageNumber = 1;
    listView = [];

    _emitPaginatedState();
  }

  List<QueryDocumentSnapshot> filterList() {
    final listFilter = listAll
        .where((document) => ((_searchTerm.isEmpty ||
                ((document.data() as Map<String, dynamic>)['headline1'])
                    .toString()
                    .toLowerCase()
                    .contains(_searchTerm.toLowerCase())) &&
            (_searchSelect.isEmpty ||
                _searchSelect.any((s) =>
                    ((document.data() as Map<String, dynamic>)['filter1'])
                        .toString()
                        .toLowerCase()
                        .contains(s.toString().toLowerCase())))))
        .toList();

    return listFilter;
  }

  // void filterQueryPaginatedList(Query newQuery) async {
  //   if (isLive) {
  //     final listener = _query
  //         .snapshots(includeMetadataChanges: includeMetadataChanges)
  //         .listen((querySnapshot) {
  //       _emitPaginatedState(querySnapshot.docs);
  //     });
  //     _streams.add(listener);
  //   } else {
  //     final querySnapshot = await _query.get(options);
  //     _emitPaginatedState(querySnapshot.docs);
  //   }
  // }

  void refreshPaginatedList() async {
    pageNumber = 1;

    if (isLive) {
      final listener = _query
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .listen((querySnapshot) {
        listAll = querySnapshot.docs;

        _emitPaginatedState();
      });

      //_streams.add(listener);
    } else {
      final querySnapshot = await _query.get(options);
      listAll = querySnapshot.docs;
      _emitPaginatedState();
    }
  }

  void fetchPaginatedList() {
    isLive ? _getLiveDocuments() : _getDocuments();
  }

  _getDocuments() async {
    try {
      if (state is PaginationInitial) {
        refreshPaginatedList();
      } else if (state is PaginationLoaded) {
        final loadedState = state as PaginationLoaded;
        if (loadedState.hasReachedEnd) return;
        _emitPaginatedState();
      }
    } on PlatformException catch (exception) {
      // ignore: avoid_print
      print(exception);
      rethrow;
    }
  }

  _getLiveDocuments() {
    if (state is PaginationInitial) {
      refreshPaginatedList();
    } else if (state is PaginationLoaded) {
      PaginationLoaded loadedState = state as PaginationLoaded;
      if (loadedState.hasReachedEnd) return;

      _emitPaginatedState();
    }
  }

  void _emitPaginatedState() {
    List<QueryDocumentSnapshot> list = listAll;

    if (_searchTerm.isNotEmpty || _searchSelect.isNotEmpty) {
      list = filterList();
    }

    final listPaginate = _paginate(list);
    listView = _mergeSnapshots(listView, listPaginate);

    final _lastDocument = list.length == listView.length;

    emit(PaginationLoaded(
      documentSnapshots: listView,
      hasReachedEnd: _lastDocument,
    ));
    pageNumber++;
  }

  List<QueryDocumentSnapshot> _paginate(List<QueryDocumentSnapshot> list) {
    final limitFinal = list.length < limit ? list.length : limit;
    return list.sublist((pageNumber - 1) * limitFinal, pageNumber * limitFinal);
  }

  List<QueryDocumentSnapshot> _mergeSnapshots(
    List<QueryDocumentSnapshot> previousList,
    List<QueryDocumentSnapshot> newList,
  ) {
    final prevIds = previousList.map((prevSnapshot) => prevSnapshot.id).toSet();
    newList.retainWhere((newSnapshot) => prevIds.add(newSnapshot.id));
    return previousList + newList;
  }

  // Query _getQuery() {
  //   // var localQuery = (_lastDocument != null)
  //   //     ? _query.startAfterDocument(_lastDocument!)
  //   //     : _startAfterDocument != null
  //   //         ? _query.startAfterDocument(_startAfterDocument!)
  //   //         : _query;
  //   // localQuery = localQuery.limit(_limit);
  //   return _query;
  // }

  void dispose() {
    for (var listener in _streams) {
      listener.cancel();
    }
  }
}
