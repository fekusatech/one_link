import 'package:flutter/material.dart';
import '../../services/geu/geu_auth_service.dart';
import 'tasks_screen.dart';
import 'self_assign_screen.dart';

/// Bottom-nav "Tugas" tab for CRO/RO. Combines Task List and Self Assign
/// under one entry point — each only shown if the logged-in user actually
/// holds the matching permission slug (crm-read-task / crm-read-self-assign),
/// same gating the rest of the CRO dashboard menu uses.
class TasksHubScreen extends StatefulWidget {
  const TasksHubScreen({super.key});

  @override
  State<TasksHubScreen> createState() => _TasksHubScreenState();
}

class _TasksHubScreenState extends State<TasksHubScreen> {
  GeuUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await GeuAuthService.getCachedUser();
    if (mounted) setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    final hasTasks = _user?.hasPermission('crm-read-task') ?? false;
    final hasSelfAssign = _user?.hasPermission('crm-read-self-assign') ?? false;

    if (hasTasks && hasSelfAssign) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Tugas'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Tugas Saya'),
                Tab(text: 'Self Assign'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              TasksScreen(embedded: true),
              SelfAssignScreen(embedded: true),
            ],
          ),
        ),
      );
    }

    if (hasTasks) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tugas Saya')),
        body: const TasksScreen(embedded: true),
      );
    }

    if (hasSelfAssign) {
      return Scaffold(
        appBar: AppBar(title: const Text('Self Assign')),
        body: const SelfAssignScreen(embedded: true),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
