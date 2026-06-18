import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../widgets/catalog_form_card.dart';
import '../widgets/catalog_tabs.dart';
import '../widgets/product_item_card.dart';
import '../widgets/service_item_card.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  static const routePath = '/catalog';
  static const routeName = 'catalog';

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final tenantId = authState is Authenticated ? authState.user.tenantId : '';

    if (tenantId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Lỗi: Không tìm thấy mã cơ sở')));
    }

    return BlocProvider(
      create: (_) => getIt<CatalogCubit>()..init(tenantId),
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatelessWidget {
  const _CatalogView();

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case "Chăm sóc da": case "Skincare": return const Color(0xFF8B5CF6);
      case "Massage": case "Body Care": return const Color(0xFF14B8A6);
      case "Tóc": return const Color(0xFFF97316);
      case "Nail": return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final violetGradient = const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    // ĐÃ FIX: Thay Colors.black10 bằng .withValues theo chuẩn mới nhất
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Text('Danh mục SP & Dịch vụ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // Tabs Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BlocBuilder<CatalogCubit, CatalogState>(
                buildWhen: (p, c) => p.currentTab != c.currentTab,
                builder: (context, state) => CatalogTabs(
                  activeTab: state.currentTab,
                  onTabChanged: (tab) => context.read<CatalogCubit>().changeTab(tab),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: BlocBuilder<CatalogCubit, CatalogState>(
                builder: (context, state) {
                  final listLength = state.currentTab == CatalogTab.service ? state.services.length : state.products.length;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Inline Add/Edit Form
                      if (state.showForm) ...[
                        CatalogFormCard(
                          key: ValueKey(state.editingItem?.id ?? 'add_${state.currentTab}'),
                          tab: state.currentTab,
                          editingItem: state.editingItem,
                          onCancel: () => context.read<CatalogCubit>().cancelEdit(),
                          onSave: (data) {
                            if (state.currentTab == CatalogTab.service) {
                              context.read<CatalogCubit>().saveService(data['id'], data['name'], data['price'], data['extra'] != null ? int.tryParse(data['extra'].toString()) ?? 30 : 30, data['category'], data['resources']);
                            } else {
                              context.read<CatalogCubit>().saveProduct(data['id'], data['name'], data['price'], data['extra'].toString(), data['category']);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // List Items
                      if (listLength == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(state.currentTab == CatalogTab.service ? Icons.content_cut : Icons.card_giftcard, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              Text('Chưa có dữ liệu hiển thị', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            ],
                          ),
                        )
                      else if (state.currentTab == CatalogTab.service)
                        ...state.services.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ServiceItemCard(service: s, themeColor: _getCategoryColor(s.category), onEdit: () => context.read<CatalogCubit>().setEditItem(s), onDelete: () => context.read<CatalogCubit>().deleteService(s.id)),
                        ))
                      else
                        ...state.products.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ProductItemCard(product: p, themeColor: _getCategoryColor(p.category), onEdit: () => context.read<CatalogCubit>().setEditItem(p), onDelete: () => context.read<CatalogCubit>().deleteProduct(p.id)),
                        )),
                    ],
                  );
                },
              ),
            ),

            // Footer Add Floating Action Button
            BlocBuilder<CatalogCubit, CatalogState>(
              buildWhen: (p, c) => p.showForm != c.showForm,
              builder: (context, state) {
                if (state.showForm) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: violetGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          // ĐÃ FIX: Thay .withOpacity bằng .withValues loại bỏ hoàn toàn cảnh báo deprecation
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // ĐÃ FIX: Viết lại cấu trúc ElevatedButton chuẩn xác thay vì gọi hàm .build() sai cú pháp
                    child: ElevatedButton(
                      onPressed: () => context.read<CatalogCubit>().toggleForm(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Thêm ${state.currentTab == CatalogTab.service ? "dịch vụ" : "sản phẩm"} mới',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
