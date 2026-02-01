import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('概览')),
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
            ),
            onPressed: () {
              context.push('/files');
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('文件浏览', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
