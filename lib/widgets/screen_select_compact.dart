
part of janus_client;

/// Minimal macOS-flavored layout: centered title, [SegmentedButton] for tabs,
/// badge-style thumbnails, and tonal share action.
///
/// Drop-in replacement for [ScreenSelectDialog] at the [showDialog] call site.
class CompactScreenSelectDialog extends ScreenSelectDialog {
  const CompactScreenSelectDialog({super.key})
      : super(
          style: const ScreenSelectDialogStyle(
            width: 560,
            height: 480,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            thumbnailBorderRadius: BorderRadius.all(Radius.circular(8)),
            screenColumns: 2,
            windowColumns: 3,
            gridSpacing: 10,
            padding: EdgeInsets.all(16),
          ),
        );

  @override
  ScreenSelectDialogState createState() => CompactScreenSelectDialogState();
}

class CompactScreenSelectDialogState extends ScreenSelectDialogState {
  @override
  Widget buildHeader(BuildContext context) {
    if (widget.headerBuilder != null) {
      return widget.headerBuilder!(context, cancel, widget.title);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: widget.style.titleStyle ?? theme.textTheme.titleMedium,
          ),
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }

  @override
  Widget buildTabs(BuildContext context) {
    if (tabController.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: SegmentedButton<SourceType>(
          style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
          showSelectedIcon: false,
          segments: [
            if (_useScreensTab)
              ButtonSegment<SourceType>(
                value: SourceType.Screen,
                label: Text(widget.screenTabLabel),
              ),
            if (_useWindowsTab)
              ButtonSegment<SourceType>(
                value: SourceType.Window,
                label: Text(widget.windowTabLabel),
              ),
          ],
          selected: {currentTabType},
          onSelectionChanged: (Set<SourceType> next) {
            final t = next.first;
            tabController.animateTo(indexForSourceType(t));
          },
        ),
      ),
    );
  }

  @override
  Widget buildThumbnail(
    BuildContext context,
    DesktopCapturerSource source,
    bool selected,
  ) {
    if (widget.thumbnailBuilder != null) {
      return super.buildThumbnail(context, source, selected);
    }
    return ScreenSelectThumbnail(
      source: source,
      selected: selected,
      selectionStyle: ScreenSelectionStyle.badge,
      onTap: () => selectSource(source),
      aspectRatio: widget.style.thumbnailAspectRatio,
      borderRadius: widget.style.thumbnailBorderRadius,
      selectedBorderWidth: widget.style.selectedBorderWidth,
      selectedBorderColor: widget.style.selectedBorderColor,
      backgroundColor: widget.style.thumbnailBackground,
      labelStyle: widget.style.thumbnailLabelStyle,
      selectedLabelStyle: widget.style.selectedThumbnailLabelStyle,
      hoverElevation: 2,
    );
  }

  @override
  Widget buildActions(BuildContext context) {
    if (widget.actionsBuilder != null) {
      return widget.actionsBuilder!(context, cancel, confirm, canConfirm);
    }
    final enabled = canConfirm;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: cancel, child: Text(widget.cancelLabel)),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: enabled ? confirm : null,
          icon: const Icon(Icons.screen_share_outlined, size: 20),
          label: Text(widget.shareLabel),
        ),
      ],
    );
  }
}
