import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animations/animations.dart';
import 'todo_service.dart';
import 'task_page.dart';
import 'auth_page.dart';
import 'util/todo_tile.dart';
import 'util/dialog_box.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage>
    with SingleTickerProviderStateMixin {
  final TodoService _service = TodoService();
  final TextEditingController _controller = TextEditingController();

  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();
  final List<QueryDocumentSnapshot> _plans = [];
  Map<String, TaskProgress> _taskProgress = {};
  StreamSubscription<QuerySnapshot>? _plansSub;
  StreamSubscription<Map<String, TaskProgress>>? _countsSub;
  bool _loaded = false;
  int _expectedCount = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _plansSub = (_service.getPlans() as Stream<QuerySnapshot>)
        .listen(_onPlansSnapshot);
    _countsSub = _service.getTaskProgressForUser().listen((progress) {
      if (!mounted) return;
      setState(() => _taskProgress = progress);
    });
  }

  @override
  void dispose() {
    _plansSub?.cancel();
    _countsSub?.cancel();
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onPlansSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;
    final newDocs = snapshot.docs;
    _expectedCount = newDocs.length;

    if (!_loaded) {
      _loaded = true;
      _fadeController.forward();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (int i = 0; i < newDocs.length; i++) {
          Future.delayed(Duration(milliseconds: 70 * i), () {
            if (!mounted) return;
            _plans.add(newDocs[i]);
            _listKey.currentState?.insertItem(
              _plans.length - 1,
              duration: const Duration(milliseconds: 400),
            );
          });
        }
      });
      return;
    }

    final newIds = newDocs.map((d) => d.id).toList();

    for (int i = _plans.length - 1; i >= 0; i--) {
      if (!newIds.contains(_plans[i].id)) {
        final removed = _plans.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildRemovingItem(removed, animation),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    final oldIds = _plans.map((d) => d.id).toList();
    for (int i = 0; i < newDocs.length; i++) {
      final newDoc = newDocs[i];
      if (!oldIds.contains(newDoc.id)) {
        _plans.insert(i, newDoc);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 350),
        );
      }
    }

    setState(() {
      for (int i = 0; i < _plans.length; i++) {
        final newIdx = newDocs.indexWhere((d) => d.id == _plans[i].id);
        if (newIdx != -1) _plans[i] = newDocs[newIdx];
      }
    });
  }

  Widget _buildRemovingItem(
    QueryDocumentSnapshot plan,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: TodoTile(
          taskName: plan["title"],
          showChevron: true,
          taskCount: _taskProgress[plan.id]?.total,
          doneCount: _taskProgress[plan.id]?.done,
        ),
      ),
    );
  }

  void _addPlan() {
    if (_controller.text.trim().isEmpty) return;
    _service.addPlan(_controller.text.trim());
    _controller.clear();
    Navigator.of(context).pop();
  }

  void _showAddDialog() {
    showAnimatedAddDialog(
      context: context,
      child: DialogBox(
        controller: _controller,
        onSave: _addPlan,
        onCancel: () {
          _controller.clear();
          Navigator.of(context).pop();
        },
        hintText: "Add a new plan!",
      ),
    );
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  void _dismissPlan(int index) {
    final plan = _plans[index];
    _plans.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => const SizedBox.shrink(),
      duration: Duration.zero,
    );
    _service.deletePlan(plan.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text("My Plans"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: "Sign out",
          ),
        ],
      ),
      floatingActionButton: _AnimatedFab(
        onPressed: _showAddDialog,
        icon: Icons.add,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: !_loaded
            ? const Center(
                key: ValueKey("loading"),
                child: CircularProgressIndicator(),
              )
            : (_plans.isEmpty && _expectedCount == 0)
                ? const _EmptyState(
                    key: ValueKey("empty"),
                    message: "No plans yet. Tap + to add one!",
                    icon: Icons.event_note,
                  )
                : FadeTransition(
                    key: const ValueKey("list"),
                    opacity: _fadeAnim,
                    child: AnimatedList(
                      key: _listKey,
                      initialItemCount: _plans.length,
                      itemBuilder: (context, index, animation) {
                        if (index >= _plans.length) {
                          return const SizedBox.shrink();
                        }
                        final plan = _plans[index];
                        return SizeTransition(
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: Dismissible(
                              key: ValueKey(plan.id),
                              direction: DismissDirection.horizontal,
                              background: _swipeBg(Alignment.centerLeft),
                              secondaryBackground:
                                  _swipeBg(Alignment.centerRight),
                              onDismissed: (_) => _dismissPlan(index),
                              child: OpenContainer(
                                closedElevation: 0,
                                openElevation: 0,
                                closedColor: Colors.transparent,
                                openColor: Colors.yellow.shade200,
                                transitionDuration:
                                    const Duration(milliseconds: 450),
                                transitionType:
                                    ContainerTransitionType.fadeThrough,
                                closedBuilder: (context, openContainer) {
                                  return TodoTile(
                                    taskName: plan["title"],
                                    showChevron: true,
                                    taskCount:
                                        _taskProgress[plan.id]?.total,
                                    doneCount: _taskProgress[plan.id]?.done,
                                    onTap: openContainer,
                                  );
                                },
                                openBuilder: (context, _) => TaskPage(
                                  planId: plan.id,
                                  planTitle: plan["title"],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _swipeBg(Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(left: 25, top: 25, right: 25),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}

class _AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const _AnimatedFab({required this.onPressed, required this.icon});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.85 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: FloatingActionButton(
        onPressed: () {
          setState(() => _pressed = true);
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) setState(() => _pressed = false);
          });
          widget.onPressed();
        },
        child: Icon(widget.icon),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  final String message;
  final IconData icon;

  const _EmptyState({super.key, required this.message, required this.icon});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.05).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Icon(widget.icon, size: 88, color: Colors.black38),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
            child: Text(
              widget.message,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
