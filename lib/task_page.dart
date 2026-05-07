import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'todo_service.dart';
import 'util/todo_tile.dart';
import 'util/dialog_box.dart';

class TaskPage extends StatefulWidget {
  final String planId;
  final String planTitle;

  const TaskPage({super.key, required this.planId, required this.planTitle});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final TodoService _service = TodoService();
  final TextEditingController _controller = TextEditingController();

  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();
  final List<QueryDocumentSnapshot> _tasks = [];
  StreamSubscription<QuerySnapshot>? _sub;
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

    _sub = (_service.getTasks(widget.planId) as Stream<QuerySnapshot>)
        .listen(_onTasksSnapshot);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTasksSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;
    final newDocs = snapshot.docs;
    _expectedCount = newDocs.length;

    if (!_loaded) {
      _loaded = true;
      _fadeController.forward();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (int i = 0; i < newDocs.length; i++) {
          Future.delayed(Duration(milliseconds: 60 * i), () {
            if (!mounted) return;
            _tasks.add(newDocs[i]);
            _listKey.currentState?.insertItem(
              _tasks.length - 1,
              duration: const Duration(milliseconds: 400),
            );
          });
        }
      });
      return;
    }

    final newIds = newDocs.map((d) => d.id).toList();

    for (int i = _tasks.length - 1; i >= 0; i--) {
      if (!newIds.contains(_tasks[i].id)) {
        final removed = _tasks.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildRemovingItem(removed, animation),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    final oldIds = _tasks.map((d) => d.id).toList();
    for (int i = 0; i < newDocs.length; i++) {
      final newDoc = newDocs[i];
      if (!oldIds.contains(newDoc.id)) {
        _tasks.insert(i, newDoc);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 350),
        );
      }
    }

    setState(() {
      for (int i = 0; i < _tasks.length; i++) {
        final newIdx = newDocs.indexWhere((d) => d.id == _tasks[i].id);
        if (newIdx != -1) _tasks[i] = newDocs[newIdx];
      }
    });
  }

  Widget _buildRemovingItem(
    QueryDocumentSnapshot task,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: TodoTile(
          taskName: task["title"],
          taskCompleted: task["isDone"],
        ),
      ),
    );
  }

  void _addTask() {
    if (_controller.text.trim().isEmpty) return;
    _service.addTask(widget.planId, _controller.text.trim());
    _controller.clear();
    Navigator.of(context).pop();
  }

  void _showAddDialog() {
    showAnimatedAddDialog(
      context: context,
      child: DialogBox(
        controller: _controller,
        onSave: _addTask,
        onCancel: () {
          _controller.clear();
          Navigator.of(context).pop();
        },
        hintText: "Add a new task!",
      ),
    );
  }

  void _dismissTask(int index) {
    final task = _tasks[index];
    _tasks.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => const SizedBox.shrink(),
      duration: Duration.zero,
    );
    _service.deleteTask(widget.planId, task.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text(widget.planTitle),
        elevation: 0,
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
            : (_tasks.isEmpty && _expectedCount == 0)
                ? const _EmptyState(
                    key: ValueKey("empty"),
                    message: "No tasks yet. Tap + to add one!",
                    icon: Icons.task_alt,
                  )
                : FadeTransition(
                    key: const ValueKey("list"),
                    opacity: _fadeAnim,
                    child: AnimatedList(
                      key: _listKey,
                      initialItemCount: _tasks.length,
                      itemBuilder: (context, index, animation) {
                        if (index >= _tasks.length) {
                          return const SizedBox.shrink();
                        }
                        final task = _tasks[index];
                        return SizeTransition(
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: Dismissible(
                              key: ValueKey(task.id),
                              direction: DismissDirection.horizontal,
                              background: _swipeBg(Alignment.centerLeft),
                              secondaryBackground:
                                  _swipeBg(Alignment.centerRight),
                              onDismissed: (_) => _dismissTask(index),
                              child: TodoTile(
                                taskName: task["title"],
                                taskCompleted: task["isDone"],
                                onChanged: (_) => _service.toggleTask(
                                  widget.planId,
                                  task.id,
                                  task["isDone"],
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
