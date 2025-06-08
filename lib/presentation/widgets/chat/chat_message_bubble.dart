import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../domain/entities/message.dart';
import '../../../data/services/file_service.dart';
import '../../blocs/chat/chat_bloc.dart';

class ChatMessageBubble extends StatefulWidget {
  final Message message;

  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _showActions = false;
  String? _selectedText;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final isLoading = widget.message.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _showActions = true),
      onExit: (_) => setState(() => _showActions = false),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, isUser),
            const SizedBox(width: AppConstants.spacingM),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.responsiveValue(
                  mobile: MediaQuery.of(context).size.width * 0.8,
                  tablet: MediaQuery.of(context).size.width * 0.7,
                  desktop: MediaQuery.of(context).size.width * 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppConstants.radiusL).copyWith(
                        bottomRight: isUser 
                            ? const Radius.circular(AppConstants.radiusS)
                            : null,
                        bottomLeft: !isUser 
                            ? const Radius.circular(AppConstants.radiusS)
                            : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          _buildLoadingIndicator(context)
                        else
                          _buildMessageContent(context, isUser),
                        if (widget.message.error != null)
                          _buildErrorMessage(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  _buildMessageInfo(context, isUser),
                  if (_showActions || ResponsiveUtils.isMobile)
                    _buildActionButtons(context, isUser),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppConstants.spacingM),
            _buildAvatar(context, isUser),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isUser) {
    return CircleAvatar(
      radius: ResponsiveUtils.responsiveValue(
        mobile: 16,
        tablet: 18,
        desktop: 20,
      ),
      backgroundColor: isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: ResponsiveUtils.responsiveValue(
          mobile: 16,
          tablet: 18,
          desktop: 20,
        ),
        color: isUser
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File type indicator if present
        if (widget.message.metadata?['fileType'] != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingS,
              vertical: AppConstants.spacingXS,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 12,
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppConstants.spacingXS),
                Text(
                  widget.message.metadata!['fileType'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isUser
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        
        // Markdown content
        _buildMarkdownContent(context, isUser),
      ],
    );
  }

  Widget _buildMarkdownContent(BuildContext context, bool isUser) {
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return MarkdownWidget(
      data: widget.message.content,
      shrinkWrap: true,
      selectable: true,
      config: MarkdownConfig(
        configs: [
          CodeConfig(
            style: TextStyle(
              backgroundColor: isUser
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
          PreConfig(
            builder: (code, language) => _buildCodeBlock(context, code, language, isUser),
          ),
          PConfig(
            textStyle: TextStyle(
              color: textColor,
              fontSize: ResponsiveUtils.responsiveFontSize(baseFontSize: 14),
            ),
          ),
          H1Config(
            style: TextStyle(
              color: textColor,
              fontSize: ResponsiveUtils.responsiveFontSize(baseFontSize: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          H2Config(
            style: TextStyle(
              color: textColor,
              fontSize: ResponsiveUtils.responsiveFontSize(baseFontSize: 18),
              fontWeight: FontWeight.bold,
            ),
          ),
          H3Config(
            style: TextStyle(
              color: textColor,
              fontSize: ResponsiveUtils.responsiveFontSize(baseFontSize: 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          BlockquoteConfig(
            textStyle: TextStyle(
              color: textColor.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code, String? language, bool isUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code block header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.05)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusS),
                topRight: Radius.circular(AppConstants.radiusS),
              ),
            ),
            child: Row(
              children: [
                if (language != null && language.isNotEmpty)
                  Text(
                    language,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isUser
                          ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Copy code block button
                    GestureDetector(
                      onTap: () => _copyCodeBlock(context, code),
                      child: Container(
                        padding: const EdgeInsets.all(AppConstants.spacingXS),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 12,
                              color: isUser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppConstants.spacingXS),
                            Text(
                              'Copy',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    // Export code block button
                    GestureDetector(
                      onTap: () => _exportCodeBlock(context, code, language ?? 'txt'),
                      child: Container(
                        padding: const EdgeInsets.all(AppConstants.spacingXS),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.1)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download,
                              size: 12,
                              color: isUser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppConstants.spacingXS),
                            Text(
                              'Export',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Code content with syntax highlighting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: HighlightView(
              code,
              language: language ?? 'plaintext',
              theme: githubTheme,
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: ResponsiveUtils.responsiveFontSize(baseFontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Text(
          'Thinking...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppConstants.spacingS),
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              widget.message.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isUser) {
    return Container(
      margin: const EdgeInsets.only(top: AppConstants.spacingS),
      child: Wrap(
        spacing: AppConstants.spacingS,
        children: [
          // Copy message button
          _buildActionButton(
            context,
            icon: Icons.copy,
            label: 'Copy',
            onTap: () => _copyToClipboard(context),
          ),
          
          // Delete message button
          _buildActionButton(
            context,
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: () => _deleteMessage(context),
          ),
          
          if (isUser) ...[
            // Edit message button
            _buildActionButton(
              context,
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () => _editMessage(context),
            ),
            
            // Resend message button
            _buildActionButton(
              context,
              icon: Icons.refresh,
              label: 'Resend',
              onTap: () => _resendMessage(context),
            ),
          ],
          
          if (!isUser) ...[
            // Regenerate response button
            _buildActionButton(
              context,
              icon: Icons.refresh,
              label: 'Regenerate',
              onTap: () => _regenerateResponse(context),
            ),
          ],
          
          // Export message button
          _buildActionButton(
            context,
            icon: Icons.download,
            label: 'Export',
            onTap: () => _exportMessage(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingXS,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppConstants.spacingXS),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInfo(BuildContext context, bool isUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTimestamp(widget.message.timestamp),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: ResponsiveUtils.responsiveFontSize(
              baseFontSize: 10,
            ),
          ),
        ),
        if (widget.message.metadata?['isMocked'] == true) ...[
          const SizedBox(width: AppConstants.spacingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXS,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusXS),
            ),
            child: Text(
              'MOCK',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyCodeBlock(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code block copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportCodeBlock(BuildContext context, String code, String language) async {
    try {
      final filePath = await FileService.exportCodeBlock(
        code: code,
        language: language,
        fileName: 'code_block_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code block exported: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ChatBloc>().add(DeleteChatMessage(messageId: widget.message.id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editMessage(BuildContext context) {
    final controller = TextEditingController(text: widget.message.content);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ChatBloc>().add(EditChatMessage(
                messageId: widget.message.id,
                newContent: controller.text,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resendMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend Message'),
        content: const Text(
          'This will remove all messages after this one and resend this message. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ChatBloc>().add(ResendChatMessage(messageId: widget.message.id));
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }

  void _regenerateResponse(BuildContext context) {
    context.read<ChatBloc>().add(RegenerateResponse(messageId: widget.message.id));
  }

  Future<void> _exportMessage(BuildContext context) async {
    try {
      final fileName = 'message_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = await FileService.saveContentToFile(
        content: widget.message.content,
        fileName: fileName,
        extension: 'md',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message exported: $filePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}