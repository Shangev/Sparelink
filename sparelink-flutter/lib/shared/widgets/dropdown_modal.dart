import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable Dropdown Modal (Bottom Sheet)
/// Migrated from React Native DropdownModal.tsx
class DropdownModal extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selectedValue;
  final Function(String) onSelect;
  final bool searchable;

  const DropdownModal({
    super.key,
    required this.title,
    required this.options,
    this.selectedValue,
    required this.onSelect,
    this.searchable = true,
  });

  @override
  State<DropdownModal> createState() => _DropdownModalState();
}

class _DropdownModalState extends State<DropdownModal> {
  late List<String> _filteredOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where((option) =>
                option.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppTheme.darkGray.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(
              top: BorderSide(color: AppTheme.glassBorder, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.glassBorder, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppTheme.white),
                    ),
                  ],
                ),
              ),

              // Search Bar (if searchable)
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterOptions,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.title.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.lightGray),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filterOptions('');
                              },
                              icon: const Icon(Icons.clear, color: AppTheme.lightGray),
                            )
                          : null,
                    ),
                  ),
                ),

              // Options List
              Expanded(
                child: _filteredOptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 48,
                              color: AppTheme.lightGray,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.lightGray,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredOptions.length,
                        itemBuilder: (context, index) {
                          final option = _filteredOptions[index];
                          final isSelected = option == widget.selectedValue;

                          return InkWell(
                            onTap: () {
                              widget.onSelect(option);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentGreen.withOpacity(0.1)
                                    : Colors.transparent,
                                border: const Border(
                                  bottom: BorderSide(
                                    color: AppTheme.glassBorder,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.accentGreen
                                            : AppTheme.white,
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.accentGreen,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show dropdown modal
Future<String?> showDropdownModal({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selectedValue,
  bool searchable = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => DropdownModal(
      title: title,
      options: options,
      selectedValue: selectedValue,
      onSelect: (value) => Navigator.pop(context, value),
      searchable: searchable,
    ),
  );
}
