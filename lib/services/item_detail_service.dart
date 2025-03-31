import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../models/database_model.dart';

/// 条目详情服务，用于管理当前选中的条目
class ItemDetailService extends ChangeNotifier {

  // 当前选中的条目
  KdbxEntry? _selectedEntry;
  KdbxGroup? _editingParent;
  KdbxEntry? _editingEntry;
  bool _addRecentSearchIfCopied = false;
  
  // 获取当前选中的条目
  KdbxEntry? get selectedEntry => _selectedEntry;
  bool get addRecentSearchIfCopied => _addRecentSearchIfCopied;
  bool get isEditing => _editingParent!=null;
  KdbxGroup? get editingParent => _editingParent;
  KdbxEntry? get editingEntry => _editingEntry;
  
  // 设置当前选中的条目
  void setSelectedEntry(KdbxEntry? entry, bool addRecentSearchIfCopied) {
    if (_selectedEntry != entry) {
      _selectedEntry = entry;
      _addRecentSearchIfCopied = addRecentSearchIfCopied;
      _editingParent = null;
      _editingEntry = null;
      notifyListeners();
    }
  }
  
  // 设置当前选中的条目
  void setEditingEntry(KdbxGroup? parent, KdbxEntry? entry) {
    if (_editingParent != parent || _editingEntry != entry) {
      _editingParent = parent;
      _editingEntry = entry;
      notifyListeners();
    }
  }
  
  // 清除当前选中的条目
  void clearSelectedEntry() {
    if (_selectedEntry != null) {
      _selectedEntry = null;
      _editingParent = null;
      _editingEntry = null;
      notifyListeners();
    }
  }
  
  // 检查指定条目是否被选中
  bool isSelected(KdbxItem entry) {
    return _selectedEntry != null && _selectedEntry!.id == entry.id;
  }
  
  // 当条目被修改时调用此方法
  void notifyEntryChanged() {
    notifyListeners();
  }
}