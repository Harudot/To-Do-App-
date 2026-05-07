import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  void addPlan(String title) {
    _firestore.collection("users").doc(userId).collection("plans").add({
      "title": title,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Stream getPlans() {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .orderBy("timestamp")
        .snapshots();
  }

  void deletePlan(String planId) {
    _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .delete();
  }

  void addTask(String planId, String title) {
    _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .collection("tasks")
        .add({
      "title": title,
      "isDone": false,
    });
  }

  Stream getTasks(String planId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .collection("tasks")
        .snapshots();
  }

  Stream<int> getTaskCount(String planId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .collection("tasks")
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<Map<String, int>> getTaskCountsForUser() {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .snapshots()
        .asyncMap((plansSnap) async {
      final counts = <String, int>{};
      for (final plan in plansSnap.docs) {
        final tasksSnap = await plan.reference.collection("tasks").get();
        counts[plan.id] = tasksSnap.docs.length;
      }
      return counts;
    });
  }

  Stream<Map<String, TaskProgress>> getTaskProgressForUser() {
    final controller = StreamController<Map<String, TaskProgress>>();
    final taskSubs = <String, StreamSubscription>{};
    final progress = <String, TaskProgress>{};
    StreamSubscription? plansSub;

    void emit() {
      if (!controller.isClosed) {
        controller.add(Map<String, TaskProgress>.from(progress));
      }
    }

    plansSub = _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .snapshots()
        .listen((plansSnap) {
      final currentIds = plansSnap.docs.map((d) => d.id).toSet();

      final removed =
          taskSubs.keys.where((id) => !currentIds.contains(id)).toList();
      for (final id in removed) {
        taskSubs[id]?.cancel();
        taskSubs.remove(id);
        progress.remove(id);
      }

      for (final plan in plansSnap.docs) {
        if (taskSubs.containsKey(plan.id)) continue;
        taskSubs[plan.id] = plan.reference
            .collection("tasks")
            .snapshots()
            .listen((tasksSnap) {
          final total = tasksSnap.docs.length;
          final done = tasksSnap.docs
              .where((d) => (d.data()["isDone"] ?? false) == true)
              .length;
          progress[plan.id] = TaskProgress(done: done, total: total);
          emit();
        });
      }

      emit();
    });

    controller.onCancel = () async {
      await plansSub?.cancel();
      for (final sub in taskSubs.values) {
        await sub.cancel();
      }
      taskSubs.clear();
    };

    return controller.stream;
  }

  void toggleTask(String planId, String taskId, bool currentValue) {
    _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .collection("tasks")
        .doc(taskId)
        .update({"isDone": !currentValue});
  }

  void deleteTask(String planId, String taskId) {
    _firestore
        .collection("users")
        .doc(userId)
        .collection("plans")
        .doc(planId)
        .collection("tasks")
        .doc(taskId)
        .delete();
  }
}

class TaskProgress {
  final int done;
  final int total;
  const TaskProgress({required this.done, required this.total});
}
