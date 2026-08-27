import 'package:flutter/material.dart';

class DataTableWidget<T> extends StatelessWidget {
  final List<DataColumn> columns;
  final List<T> items;
  final DataRow Function(T item) rowBuilder;
  final bool isLoading;
  final String emptyMessage;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 48, color: Theme.of(context).dividerColor),
              const SizedBox(height: 16),
              Text(emptyMessage, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        dataRowMaxHeight: 60,
        columns: columns,
        rows: items.map((e) => rowBuilder(e)).toList(),
      ),
    );
  }
}
