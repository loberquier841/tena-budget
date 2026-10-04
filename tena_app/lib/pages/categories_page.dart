import 'package:flutter/material.dart';

import '../services/category_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryService.getCategories();

    if (!mounted) return;

    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();

        return AlertDialog(
          title: const Text('Nouvelle catégorie'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom',
              hintText: 'Ex. Restaurants',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;

    final exists = _categories.any(
      (category) => category.toLowerCase() == name.trim().toLowerCase(),
    );

    if (exists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette catégorie existe déjà.')),
      );

      return;
    }

    await CategoryService.addCategory(name);

    await _loadCategories();
  }

  Future<void> _renameCategory(String category) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: category);

        return AlertDialog(
          title: const Text('Modifier la catégorie'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;

    final exists = _categories.any(
      (item) =>
          item.toLowerCase() == name.trim().toLowerCase() && item != category,
    );

    if (exists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette catégorie existe déjà.')),
      );

      return;
    }

    await CategoryService.renameCategory(category, name);

    await _loadCategories();
  }

  Future<void> _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la catégorie ?'),
          content: Text(
            'La catégorie « $category » sera supprimée de la liste.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await CategoryService.deleteCategory(category);

    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catégories',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('Organise tes revenus et tes dépenses.'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _categories.isEmpty
                  ? const Center(child: Text('Aucune catégorie.'))
                  : ListView.separated(
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final category = _categories[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(category[0].toUpperCase()),
                            ),
                            title: Text(category),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameCategory(category);
                                } else if (value == 'delete') {
                                  _deleteCategory(category);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('Modifier'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Supprimer'),
                                  ),
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
    );
  }
}
