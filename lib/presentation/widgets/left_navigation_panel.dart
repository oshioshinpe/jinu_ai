// lib/presentation/widgets/left_navigation_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';
import '../providers/sidebar_provider.dart';
import '../providers/chat_providers.dart'; // For chat actions
import '../../data/models/chat_session_item.dart'; // Import model for type hint

class LeftNavigationPanel extends ConsumerWidget {
  final bool isMobileLayout;
  final bool isCollapsed; // Only relevant for desktop

  const LeftNavigationPanel({
    super.key,
    required this.isMobileLayout,
    required this.isCollapsed, // Pass collapsed state
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers needed for display and actions
    final chatHistory = ref.watch(chatSessionsProvider); // Watch the filtered list
    final currentChatId = ref.watch(activeChatIdProvider);
    final chatController = ref.read(chatControllerProvider.notifier); // For actions
    // Also watch the active session to ensure title updates are reflected
    final activeSession = ref.watch(activeChatSessionProvider);
    // No need to watch sidebarCollapsedProvider directly if passed via constructor

    final bool showText = !isCollapsed || isMobileLayout; // Determine when to show text

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header / Logo ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: isCollapsed && !isMobileLayout
              ? IconButton( // Icon when collapsed
                    icon: const Icon(Icons.interests_rounded), // Use a relevant icon
                    tooltip: 'AI Studio',
                    onPressed: () {
                        // Maybe expand sidebar on icon click?
                        ref.read(sidebarCollapsedProvider.notifier).state = false;
                    },
                    color: Colors.grey[300],
               )
              : Row( // Logo/Title and potentially a collapse button when expanded
                 children: [
                   Icon(Icons.interests_rounded, color: Colors.blue[300], size: 24),
                   const SizedBox(width: 8),
                   const Text( 'AI Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
                    const Spacer(),
                    // Show collapse button only when expanded on desktop
                   if (!isCollapsed && !isMobileLayout)
                      IconButton(
                         icon: const Icon(Icons.chevron_left, size: 20),
                         onPressed: () => ref.read(sidebarCollapsedProvider.notifier).state = true,
                         tooltip: 'Collapse sidebar',
                         color: Colors.grey[400],
                         padding: EdgeInsets.zero,
                         constraints: const BoxConstraints(),
                      ),
                 ],
              ),
        ),

        // --- New Chat Button ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: isCollapsed && !isMobileLayout
              ? IconButton(
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: "New Chat",
                  onPressed: () => chatController.createNewChat(),
                  color: Colors.grey[300],
                 )
              : ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New Chat'),
                  onPressed: () {
                       chatController.createNewChat();
                       if (isMobileLayout) Navigator.pop(context); // Close drawer
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40), // Full width
                    // Use theme colors or define explicitly
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                     alignment: Alignment.centerLeft, // Align icon/text left
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                  ),
                 ),
        ),
        const SizedBox(height: 8),

        // --- History Section ---
        if (showText)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("History", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        if (!showText) // Show icon or divider when collapsed
           const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              //child: Divider(indent: 16, endIndent: 16), // Use divider when collapsed
              child: Center(child: Icon(Icons.history, size: 20, color: Color.fromARGB(255, 189, 189, 189))),
           ),


        // --- Chat History List ---
        Expanded(
          child: chatHistory.isEmpty
            ? (showText ? const Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey))) : const SizedBox.shrink())
            : ListView.builder(
                padding: EdgeInsets.zero, // Remove default padding
                itemCount: chatHistory.length,
                itemBuilder: (context, index) {
                  final session = chatHistory[index];
                  final isSelected = session.id == currentChatId;

                  return _buildHistoryItem(
                    context,
                    ref,
                    session,
                    isSelected,
                    isCollapsed: isCollapsed && !isMobileLayout,
                    isMobile: isMobileLayout,
                    onTap: () {
                      chatController.selectChat(session.id);
                      if (isMobileLayout) Navigator.pop(context); // Close drawer
                    },
                     onDelete: () => _confirmDelete(context, ref, chatController, session.id, currentChatId),
                  );
                },
            ),
        ),


        // --- Footer section / Collapse button (for desktop expanded state) ---
        if (!isMobileLayout) ...[
          const Divider(height: 1, color: Colors.grey),
          Align(
             alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
             child: IconButton(
                 icon: Icon(isCollapsed ? Icons.chevron_right : Icons.chevron_left, size: 20),
                 onPressed: () => ref.read(sidebarCollapsedProvider.notifier).update((state) => !state),
                 tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                 color: Colors.grey[400],
                 padding: const EdgeInsets.all(12),
             ),
          ),
        ] else ...[
           // Optional: Add footer actions for the mobile drawer if needed
        ]
      ],
    );
  }

  // Extracted History Item Widget
  Widget _buildHistoryItem(
      BuildContext context,
      WidgetRef ref,
      ChatSessionItem session, // Pass the whole session
      bool isSelected, {
        required bool isCollapsed,
        required bool isMobile,
        required VoidCallback onTap,
        required VoidCallback onDelete,
      }) {
    final showText = !isCollapsed || isMobile;
    final displayTitle = session.displayTitle; // Use the getter from the model

    return Material(
      color: isSelected ? Colors.grey[700] : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0), // Adjust padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Row(
            children: [
              if (showText) // Expanded Text and Delete Button
                Expanded(
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[300], // Brighter non-selected text
                        fontSize: 13.5, // Slightly larger
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              else // Collapsed Icon
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add padding around icon
                   child: Icon(Icons.chat_bubble_outline, size: 18, color: isSelected ? Colors.white : Colors.grey[400]),
                 ),

              // Show delete only when expanded and selected (or maybe on hover?)
              if (showText && isSelected)
                SizedBox( // Constrain icon button size
                   width: 24, height: 24,
                   child: IconButton(
                       icon: Icon(Icons.delete_outline, size: _if(isSelected, 17.0, 16.0) , color: Colors.grey[500]), // Slightly larger when selected?
                       padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                       tooltip: 'Delete Chat',
                       onPressed: onDelete,
                       splashRadius: 16,
                   ),
                )
            ],
          ),
        ),
      ),
    );
  }

 // Helper for conditional value
 T _if<T>(bool condition, T valueTrue, T valueFalse) {
      return condition ? valueTrue : valueFalse;
  }

 // Confirmation Dialog for Deletion
 void _confirmDelete(BuildContext context, WidgetRef ref, ChatController controller, String sessionId, String? currentChatId) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text("Delete Chat?"),
           content: const Text("Are you sure you want to permanently delete this chat session?"),
            actions: [
                 TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
                 TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                       onPressed: () {
                          controller.deleteChat(sessionId); // Call controller method
                          Navigator.of(ctx).pop(); // Close dialog
                      },
                     child: const Text("Delete")),
            ],
        )
    );
 }
}