
part of janus_client;

/// Wider “studio” layout: left rail for category + source list, large preview
/// on the right, outlined cancel + filled share.
///
/// Drop-in replacement for [ScreenSelectDialog] at the [showDialog] call site.
class SidebarScreenSelectDialog extends ScreenSelectDialog {
  const SidebarScreenSelectDialog({super.key})
      : super(
          style: const ScreenSelectDialogStyle(
            width: 880,
            height: 600,
            borderRadius: BorderRadius.all(Radius.circular(18)),
            thumbnailBorderRadius: BorderRadius.all(Radius.circular(12)),
            padding: EdgeInsets.zero,
            contentPadding: EdgeInsets.all(20),
            selectedBorderWidth: 0,
            screenColumns: 2,
            windowColumns: 3,
          ),
        );

  @override
  ScreenSelectDialogState createState() => SidebarScreenSelectDialogState();
}

class SidebarScreenSelectDialogState extends ScreenSelectDialogState {
  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a source to share',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _categoryRail(context),
                Expanded(child: _sourceList(context)),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: widget.style.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _previewPane(context)),
                const SizedBox(height: 16),
                buildActions(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryRail(BuildContext context) {
    if (tabController.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          if (_useScreensTab)
            _RailChoice(
              icon: Icons.desktop_windows_outlined,
              label: widget.screenTabLabel,
              selected: currentTabType == SourceType.Screen,
              onTap: () => tabController.animateTo(indexForSourceType(SourceType.Screen)),
            ),
          if (_useWindowsTab)
            _RailChoice(
              icon: Icons.window_outlined,
              label: widget.windowTabLabel,
              selected: currentTabType == SourceType.Window,
              onTap: () => tabController.animateTo(indexForSourceType(SourceType.Window)),
            ),
        ],
      ),
    );
  }

  Widget _sourceList(BuildContext context) {
    final items = sourcesOfType(currentTabType);
    if (shouldShowLoadingForType(currentTabType)) {
      return Center(child: buildLoading(context));
    }
    if (items.isEmpty) {
      final msg = currentTabType == SourceType.Screen ? widget.emptyScreenMessage : widget.emptyWindowMessage;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      itemBuilder: (context, i) {
        final s = items[i];
        final sel = selectedSource?.id == s.id;
        return ListTile(
          dense: true,
          selected: sel,
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.35),
          leading: SizedBox(
            width: 40,
            height: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: s.thumbnail != null
                  ? Image.memory(
                      s.thumbnail!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Center(
                      child: Icon(
                        Icons.layers_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
            ),
          ),
          title: Text(
            s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          onTap: () => selectSource(s),
        );
      },
    );
  }

  Widget _previewPane(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (selectedSource == null) {
      return _previewEmpty(context);
    }
    final s = selectedSource!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (s.thumbnail != null)
                    Image.memory(
                      s.thumbnail!,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 56,
                        color: colorScheme.outline,
                      ),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          s.name,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              s.type == SourceType.Screen ? Icons.desktop_windows_outlined : Icons.window_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${s.type == SourceType.Screen ? 'Screen' : 'Window'} · ${s.id}',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewEmpty(BuildContext context) {
    if (widget.emptyBuilder != null) {
      final msg = currentTabType == SourceType.Screen ? widget.emptyScreenMessage : widget.emptyWindowMessage;
      return widget.emptyBuilder!(context, currentTabType, msg);
    }
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.desktop_windows_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a screen or window',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Pick an item from the list to preview it here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildActions(BuildContext context) {
    if (widget.actionsBuilder != null) {
      return widget.actionsBuilder!(context, cancel, confirm, canConfirm);
    }
    final mq = MediaQuery.sizeOf(context);
    final narrow = mq.width < 520;
    final enabled = canConfirm;
    final share = FilledButton.icon(
      onPressed: enabled ? confirm : null,
      icon: const Icon(Icons.screen_share_outlined),
      label: Text(widget.shareLabel),
    );
    final cancelBtn = OutlinedButton(
      onPressed: cancel,
      child: Text(widget.cancelLabel),
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          share,
          const SizedBox(height: 8),
          cancelBtn,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        cancelBtn,
        const SizedBox(width: 12),
        share,
      ],
    );
  }
}

class _RailChoice extends StatelessWidget {
  const _RailChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                    ),
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
