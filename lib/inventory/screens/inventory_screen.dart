import 'dart:async';
import 'package:flutter/material.dart';
import '../data/inventory_ffi.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // ── App Palette (matches the rest of the app) ──────────────────────────────
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _textSub = Color(0xFF94A3B8);
  static const _accent = Color(0xFF3B82F6);
  // ──────────────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  List<Product> _products = [];
  InventoryStats _stats = InventoryStats(
    totalProducts: 0,
    lowStockItems: 0,
    totalValue: 0.0,
  );
  Timer? _debounce;

  String _selectedCategory = "All Categories";
  String _searchQuery = "";

  final List<String> _categories = [
    "All Categories",
    "Electronics",
    "Audio",
    "Accessories",
    "Peripherals",
  ];

  void _updateInventory() {
    setState(() => _isLoading = true);
    InventoryFFI.instance
        .getFilteredInventory(_searchQuery, _selectedCategory)
        .then((products) {
          if (mounted) {
            setState(() {
              _products = products;
              _isLoading = false;
            });
            _loadData(); // تحديث إحصائيات الكروت أيضاً
          }
        })
        .catchError((e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading products: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _updateInventory();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateInventory();
  }

  Future<void> _loadData() async {
    try {
      final stats = await InventoryFFI.instance.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading inventory: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Delete Dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border),
        ),
        title: const Text(
          'Delete Product?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${product.name}"?',
              style: const TextStyle(color: _textSub),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The product will be removed from the inventory.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _textSub),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await InventoryFFI.instance.deleteProduct(product.id);
              if (ok) {
                _loadData();
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete product'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Add Product Dialog ─────────────────────────────────────────────────────
  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final purchCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String newCategory = "Electronics";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.inventory_2, color: _accent),
                          SizedBox(width: 8),
                          Text(
                            'Add New Product',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _textSub),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildField(
                    'Product Name',
                    nameCtrl,
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    'Barcode / SKU',
                    barcodeCtrl,
                    icon: Icons.qr_code,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: newCategory,
                    dropdownColor: _surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: _textSub),
                      prefixIcon: const Icon(
                        Icons.category,
                        color: _textSub,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _bg,
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _accent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _categories.where((c) => c != "All Categories").map((
                      c,
                    ) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => newCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          'Purchase Price',
                          purchCtrl,
                          isNumber: true,
                          icon: Icons.attach_money,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildField(
                          'Selling Price',
                          sellCtrl,
                          isNumber: true,
                          icon: Icons.sell_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    'Initial Quantity',
                    qtyCtrl,
                    isNumber: true,
                    icon: Icons.numbers,
                  ),
                  const SizedBox(height: 20),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFF59E0B),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Important:',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '• Ensure barcode is unique.',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '• Stock warnings appear automatically.',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(foregroundColor: _textSub),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);
                            final ok = await InventoryFFI.instance.addProduct(
                              barcodeCtrl.text,
                              nameCtrl.text,
                              newCategory,
                              double.tryParse(purchCtrl.text) ?? 0.0,
                              double.tryParse(sellCtrl.text) ?? 0.0,
                              int.tryParse(qtyCtrl.text) ?? 0,
                            );
                            if (ok) {
                              _loadData();
                            } else {
                              setState(() => _isLoading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add product. Please check console logs for the error code.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Add Product'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Text Field Helper ──────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    IconData? icon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSub),
        prefixIcon: icon != null ? Icon(icon, color: _textSub, size: 20) : null,
        filled: true,
        fillColor: _bg,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ── Main Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Inventory Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Stat Cards ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Products',
                    _stats.totalProducts.toString(),
                    Icons.inventory_2_outlined,
                    const Color(0xFF10B981),
                    const Color(0xFF064E3B),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _statCard(
                    'Low Stock Items',
                    _stats.lowStockItems.toString(),
                    Icons.warning_amber_rounded,
                    const Color(0xFFF59E0B),
                    const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _statCard(
                    'Total Value',
                    '\$${_stats.totalValue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    _accent,
                    const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
            // ─── الجزء المفقود (Search & Category Filter) ───
            const SizedBox(height: 32), // مسافة بعد الكروت
            Row(
              children: [
                // 1. خانة البحث (Search Bar)
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B), // لون الـ Surface
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TextField(
                      onChanged: _onSearchChanged, // الدالة اللي بكلم بيها الـ C++
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Search by product name or SKU...",
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 2. قائمة التصنيفات (Dropdown)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        icon: const Icon(Icons.filter_list, color: Color(0xFF94A3B8)),
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                            _updateInventory(); // تحديث الجدول بناءً على التصنيف
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24), // مسافة قبل الجدول

            // ── Products Table ───────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _accent),
                      )
                    : _products.isEmpty
                    ? const Center(
                        child: Text(
                          'No products available.',
                          style: TextStyle(color: _textSub, fontSize: 16),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFF0F172A),
                          ),
                          dataRowColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.hovered)) {
                              return Colors.white.withOpacity(0.04);
                            }
                            return Colors.transparent;
                          }),
                          dividerThickness: 1,
                          headingTextStyle: const TextStyle(
                            color: _textSub,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          columns: const [
                            DataColumn(label: Text('ID')),
                            DataColumn(label: Text('Barcode')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Selling Price')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _products.map((p) {
                            final lowStock = p.stockQuantity <= 10;
                            final stockColor = lowStock
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981);
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '#${p.id}',
                                    style: const TextStyle(color: _textSub),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    p.barcode,
                                    style: const TextStyle(color: _textSub),
                                  ),
                                ),
                                DataCell(Text(p.name)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.category,
                                      style: const TextStyle(
                                        color: _accent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '\$${p.sellingPrice.toStringAsFixed(2)}',
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stockColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: stockColor.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '${p.stockQuantity}',
                                      style: TextStyle(
                                        color: stockColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFEF4444),
                                    ),
                                    onPressed: () => _showDeleteDialog(p),
                                    tooltip: 'Delete Product',
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat Card Widget ───────────────────────────────────────────────────────
  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color iconBg,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: _textSub, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
