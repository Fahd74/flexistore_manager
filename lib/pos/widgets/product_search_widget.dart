import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/cart_state.dart';
import '../../installments/data/app_data_store.dart';
import '../../core/db_models.dart';

class ProductSearchWidget extends StatefulWidget {
  const ProductSearchWidget({super.key});

  @override
  State<ProductSearchWidget> createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  String _query = '';
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();

  final List<String> _categories = [
    'All', 'Phones', 'Laptops', 'Tablets', 'Audio', 'Wearables', 'Accessories'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildTopBar(),
      const SizedBox(height: 20),
      _buildCategoryFilters(),
      const SizedBox(height: 20),
      Expanded(
        child: ValueListenableBuilder<List<DbProduct>>(
          valueListenable: AppDataStore.instance.productsNotifier,
          builder: (context, products, _) {
            final filtered = products.where((p) {
              final q = _query.toLowerCase();
              final matchesQuery = q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.barcode.toLowerCase().contains(q);
              
              final bool matchesCategory = _selectedCategory == 'All' || 
                  (p.name.toLowerCase().contains(_selectedCategory.toLowerCase())); // Demo logic

              return matchesQuery && matchesCategory;
            }).toList();

            return _buildTable(filtered);
          },
        ),
      ),
    ]);
  }

  Widget _buildTopBar() {
    return Row(children: [
      Expanded(
          child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search products or scan barcode...',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          )),
          const VerticalDivider(color: Color(0xFF334155), indent: 12, endIndent: 12),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.barcode_reader, color: Colors.white38, size: 22)),
        ]),
      )),
      const SizedBox(width: 16),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(children: [
          Icon(Icons.history, color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 8),
          const Text('Return Item', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF334155) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF475569) : const Color(0xFF1E293B),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(List<DbProduct> products) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: Column(children: [
        _buildTableHeader(),
        const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
        Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No products found', style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: products.length,
                    itemBuilder: (ctx, i) => _buildTableRow(products[i], i % 2 == 1),
                  )),
      ]),
    );
  }

  Widget _buildTableHeader() {
    const s = TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: const [
        Expanded(flex: 4, child: Text('PRODUCT NAME', style: s)),
        Expanded(flex: 2, child: Text('BARCODE', style: s)),
        Expanded(flex: 2, child: Text('PRICE', style: s)),
        Expanded(flex: 2, child: Text('STOCK', style: s)),
        SizedBox(width: 80, child: Text('ACTION', style: s, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _buildTableRow(DbProduct p, bool isAlt) {
    final bool isLowStock = p.stockQuantity < 10;
    final Color stockColor = isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isAlt ? Colors.white.withOpacity(0.01) : Colors.transparent,
      ),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(p.stockQuantity < 5 ? 'Critical Stock' : 'Active', 
                  style: TextStyle(color: p.stockQuantity < 5 ? const Color(0xFFEF4444) : const Color(0xFF64748B), fontSize: 11)),
              ],
            )),
        Expanded(
            flex: 2,
            child: Text(p.barcode, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'monospace'))),
        Expanded(
            flex: 2,
            child: Text('\$${p.sellingPrice.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 15, fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: stockColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('${p.stockQuantity} units',
                    style: TextStyle(color: stockColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            )),
        SizedBox(
          width: 80,
          child: ElevatedButton(
            onPressed: () => CartState.instance.addToCart(CartItem(
                productId: p.id,
                name: p.name,
                price: p.sellingPrice)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
