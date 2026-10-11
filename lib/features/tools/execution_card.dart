import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'execution_controller.dart';

class ExecutionCard extends ConsumerWidget {
  const ExecutionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execution = ref.watch(executionProvider);
    final idle = execution.phase == ExecutionPhase.idle;
    return Semantics(
      label: '執行狀態區域',
      child: Card.outlined(
        key: const ValueKey('execution-status-card'),
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          height: idle ? 180 : 300,
          width: double.infinity,
          child: idle
              ? const Center(child: Text('尚未執行'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        execution.message,
                        style: TextStyle(
                          color: execution.phase == ExecutionPhase.failed
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                      if (execution.isBusy) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: execution.progress),
                        if (execution.progress != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(execution.progress! * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          primary: false,
                          reverse: true,
                          child: SelectableText(execution.logs.join('\n')),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
