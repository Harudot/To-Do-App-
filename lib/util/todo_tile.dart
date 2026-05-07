import 'package:flutter/material.dart';

class TodoTile extends StatefulWidget {
  final String taskName;
  final bool? taskCompleted;
  final Function(bool?)? onChanged;
  final VoidCallback? onTap;
  final int? taskCount;
  final int? doneCount;
  final bool showChevron;

  const TodoTile({
    super.key,
    required this.taskName,
    this.taskCompleted,
    this.onChanged,
    this.onTap,
    this.taskCount,
    this.doneCount,
    this.showChevron = false,
  });

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.taskCompleted == true;

    return Padding(
      padding: const EdgeInsets.only(left: 25, top: 25, right: 25),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _setPressed(true) : null,
        onTapCancel: widget.onTap != null ? () => _setPressed(false) : null,
        onTapUp: widget.onTap != null ? (_) => _setPressed(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: isDone ? 0.55 : 1.0,
            duration: const Duration(milliseconds: 350),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDone ? Colors.yellow.shade300 : Colors.yellow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: _pressed ? 2 : 6,
                    offset: Offset(0, _pressed ? 1 : 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.taskCompleted != null) _buildAnimatedCheckbox(),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDone ? Colors.black54 : Colors.black,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationThickness: 2,
                        fontWeight:
                            isDone ? FontWeight.normal : FontWeight.w500,
                      ),
                      child: Text(widget.taskName),
                    ),
                  ),
                  if (widget.taskCount != null) _buildCountBadge(),
                  if (widget.showChevron)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCheckbox() {
    final isDone = widget.taskCompleted == true;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => widget.onChanged?.call(!isDone),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone ? Colors.black : Colors.transparent,
            border: Border.all(
              color: isDone ? Colors.black : Colors.black54,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: isDone
                ? const Icon(
                    Icons.check,
                    key: ValueKey("checked"),
                    color: Colors.yellow,
                    size: 18,
                  )
                : const SizedBox(key: ValueKey("unchecked")),
          ),
        ),
      ),
    );
  }

  Widget _buildCountBadge() {
    final total = widget.taskCount ?? 0;
    final done = widget.doneCount ?? 0;
    final allDone = total > 0 && done == total;
    final label = widget.doneCount != null ? "$done/$total" : "$total";
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey(label),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: allDone ? Colors.green.shade700 : Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allDone ? Icons.check_circle : Icons.checklist,
              size: 14,
              color: Colors.yellow,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
