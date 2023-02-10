import 'package:flutter/widgets.dart';

class PaginateChangeListener extends ChangeNotifier {}

class PaginateRefreshedChangeListener extends PaginateChangeListener {
  PaginateRefreshedChangeListener();

  bool _refreshed = false;

  set refreshed(bool value) {
    _refreshed = value;
    if (value) {
      notifyListeners();
    }
  }

  bool get refreshed {
    return _refreshed;
  }
}

class PaginateFilterChangeListener extends PaginateChangeListener {
  PaginateFilterChangeListener();

  late String _filterTerm;

  set searchTerm(String value) {
    _filterTerm = value;
    notifyListeners();
  }

  String get searchTerm {
    return _filterTerm;
  }

  late List<String> _filterSelect;

  set searchSelect(List<String> value) {
    _filterSelect = value;
    notifyListeners();
  }

  List<String> get searchSelect {
    return _filterSelect;
  }
}

class PaginateQueryChangeListener extends PaginateChangeListener {
  PaginateQueryChangeListener();

  dynamic? _query;

  set query(dynamic value) {
    _query = value;
    notifyListeners();
  }

  dynamic? get query {
    return _query;
  }
}
