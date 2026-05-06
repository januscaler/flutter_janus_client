
part of janus_client;

// --- Style -----------------------------------------------------------------

/// Visual tokens for [ScreenSelectDialog]. Pass [copyWith] overrides for
/// branding; unspecified fields fall back to sensible defaults at build time.
class ScreenSelectDialogStyle {
  const ScreenSelectDialogStyle({
    this.width = 720,
    this.height = 580,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.elevation = 8,
    this.padding = const EdgeInsets.all(16),
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.gridSpacing = 10,
    this.screenColumns = 2,
    this.windowColumns = 3,
    this.thumbnailAspectRatio = 16 / 10,
    this.selectedBorderColor,
    this.thumbnailBackground,
    this.selectedBorderWidth = 2.5,
    this.thumbnailBorderRadius = const BorderRadius.all(Radius.circular(10)),
    this.titleStyle,
    this.tabLabelStyle,
    this.thumbnailLabelStyle,
    this.selectedThumbnailLabelStyle,
    this.backgroundColor,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double elevation;
  final EdgeInsets padding;
  final EdgeInsets contentPadding;
  final double gridSpacing;
  final int screenColumns;
  final int windowColumns;
  final double thumbnailAspectRatio;
  final Color? selectedBorderColor;
  final Color? thumbnailBackground;
  final double selectedBorderWidth;
  final BorderRadius thumbnailBorderRadius;
  final TextStyle? titleStyle;
  final TextStyle? tabLabelStyle;
  final TextStyle? thumbnailLabelStyle;
  final TextStyle? selectedThumbnailLabelStyle;
  final Color? backgroundColor;

  ScreenSelectDialogStyle copyWith({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    double? elevation,
    EdgeInsets? padding,
    EdgeInsets? contentPadding,
    double? gridSpacing,
    int? screenColumns,
    int? windowColumns,
    double? thumbnailAspectRatio,
    Color? selectedBorderColor,
    Color? thumbnailBackground,
    double? selectedBorderWidth,
    BorderRadius? thumbnailBorderRadius,
    TextStyle? titleStyle,
    TextStyle? tabLabelStyle,
    TextStyle? thumbnailLabelStyle,
    TextStyle? selectedThumbnailLabelStyle,
    Color? backgroundColor,
  }) {
    return ScreenSelectDialogStyle(
      width: width ?? this.width,
      height: height ?? this.height,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      contentPadding: contentPadding ?? this.contentPadding,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      screenColumns: screenColumns ?? this.screenColumns,
      windowColumns: windowColumns ?? this.windowColumns,
      thumbnailAspectRatio: thumbnailAspectRatio ?? this.thumbnailAspectRatio,
      selectedBorderColor: selectedBorderColor ?? this.selectedBorderColor,
      thumbnailBackground: thumbnailBackground ?? this.thumbnailBackground,
      selectedBorderWidth: selectedBorderWidth ?? this.selectedBorderWidth,
      thumbnailBorderRadius: thumbnailBorderRadius ?? this.thumbnailBorderRadius,
      titleStyle: titleStyle ?? this.titleStyle,
      tabLabelStyle: tabLabelStyle ?? this.tabLabelStyle,
      thumbnailLabelStyle: thumbnailLabelStyle ?? this.thumbnailLabelStyle,
      selectedThumbnailLabelStyle: selectedThumbnailLabelStyle ?? this.selectedThumbnailLabelStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenSelectDialogStyle &&
        other.width == width &&
        other.height == height &&
        other.borderRadius == borderRadius &&
        other.elevation == elevation &&
        other.padding == padding &&
        other.contentPadding == contentPadding &&
        other.gridSpacing == gridSpacing &&
        other.screenColumns == screenColumns &&
        other.windowColumns == windowColumns &&
        other.thumbnailAspectRatio == thumbnailAspectRatio &&
        other.selectedBorderColor == selectedBorderColor &&
        other.thumbnailBackground == thumbnailBackground &&
        other.selectedBorderWidth == selectedBorderWidth &&
        other.thumbnailBorderRadius == thumbnailBorderRadius &&
        other.titleStyle == titleStyle &&
        other.tabLabelStyle == tabLabelStyle &&
        other.thumbnailLabelStyle == thumbnailLabelStyle &&
        other.selectedThumbnailLabelStyle == selectedThumbnailLabelStyle &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode => Object.hashAll([
        width,
        height,
        borderRadius,
        elevation,
        padding,
        contentPadding,
        gridSpacing,
        screenColumns,
        windowColumns,
        thumbnailAspectRatio,
        selectedBorderColor,
        thumbnailBackground,
        selectedBorderWidth,
        thumbnailBorderRadius,
        titleStyle,
        tabLabelStyle,
        thumbnailLabelStyle,
        selectedThumbnailLabelStyle,
        backgroundColor,
      ]);
}

// --- Thumbnail -------------------------------------------------------------

enum ScreenSelectionStyle {
  /// Primary-colored border around the thumbnail when selected.
  ring,

  /// Small check badge in the corner when selected (see [CompactScreenSelectDialog]).
  badge,
}

typedef ScreenSourceTapCallback = void Function(DesktopCapturerSource source);

typedef ScreenSelectHeaderBuilder = Widget Function(
  BuildContext context,
  VoidCallback onClose,
  String title,
);

typedef ScreenThumbnailBuilder = Widget Function(
  BuildContext context,
  DesktopCapturerSource source,
  bool selected,
  VoidCallback onTap,
);

typedef ScreenSelectActionsBuilder = Widget Function(
  BuildContext context,
  VoidCallback onCancel,
  VoidCallback onShare,
  bool shareEnabled,
);

typedef ScreenSelectEmptyBuilder = Widget Function(
  BuildContext context,
  SourceType type,
  String message,
);

typedef ScreenSelectLoadingBuilder = Widget Function(BuildContext context);

/// Single desktop-capture source tile with live thumbnail/name updates.
class ScreenSelectThumbnail extends StatefulWidget {
  const ScreenSelectThumbnail({
    super.key,
    required this.source,
    required this.selected,
    required this.onTap,
    this.selectionStyle = ScreenSelectionStyle.ring,
    this.aspectRatio = 16 / 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.selectedBorderWidth = 2.5,
    this.selectedBorderColor,
    this.backgroundColor,
    this.labelStyle,
    this.selectedLabelStyle,
    this.hoverElevation = 2,
  });

  final DesktopCapturerSource source;
  final bool selected;
  final VoidCallback onTap;
  final ScreenSelectionStyle selectionStyle;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final double selectedBorderWidth;
  final Color? selectedBorderColor;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final TextStyle? selectedLabelStyle;
  final double hoverElevation;

  @override
  State<ScreenSelectThumbnail> createState() => _ScreenSelectThumbnailState();
}

class _ScreenSelectThumbnailState extends State<ScreenSelectThumbnail> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(widget.source.onThumbnailChanged.stream.listen((_) {
      if (mounted) setState(() {});
    }));
    _subscriptions.add(widget.source.onNameChanged.stream.listen((_) {
      if (mounted) setState(() {});
    }));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = widget.backgroundColor ?? colorScheme.surfaceContainerHighest;
    final ringColor = widget.selectedBorderColor ?? colorScheme.primary;
    final baseLabel = widget.labelStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant);
    final selLabel = widget.selectedLabelStyle ??
        baseLabel.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        );

    final thumb = widget.source.thumbnail != null
        ? Image.memory(
            widget.source.thumbnail!,
            gaplessPlayback: true,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          )
        : Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: colorScheme.outline,
            ),
          );

    Widget card = Material(
      color: bg,
      elevation: _hover && !widget.selected ? widget.hoverElevation : 0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumb,
              if (widget.selectionStyle == ScreenSelectionStyle.badge && widget.selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ringColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.selectionStyle == ScreenSelectionStyle.ring && widget.selected) {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(color: ringColor, width: widget.selectedBorderWidth),
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: card,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card,
          const SizedBox(height: 6),
          Tooltip(
            message: widget.source.name,
            child: Text(
              widget.source.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: widget.selected ? selLabel : baseLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy thumbnail tile; prefer [ScreenSelectThumbnail].
@Deprecated('Use ScreenSelectThumbnail instead')
class ThumbnailWidget extends StatefulWidget {
  const ThumbnailWidget({
    Key? key,
    required this.source,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  final DesktopCapturerSource source;
  final bool selected;
  final ScreenSourceTapCallback onTap;

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  @override
  Widget build(BuildContext context) {
    return ScreenSelectThumbnail(
      source: widget.source,
      selected: widget.selected,
      onTap: () => widget.onTap(widget.source),
    );
  }
}

// --- Dialog ----------------------------------------------------------------

/// Picker dialog for desktop display/window capture ([DesktopCapturerSource]).
///
/// Customize via [style], optional builders, or subclass [ScreenSelectDialog]
/// and override methods on [ScreenSelectDialogState].
class ScreenSelectDialog extends StatefulWidget {
  const ScreenSelectDialog({
    super.key,
    this.title = 'Choose what to share',
    this.screenTabLabel = 'Entire Screen',
    this.windowTabLabel = 'Window',
    this.cancelLabel = 'Cancel',
    this.shareLabel = 'Share',
    this.emptyScreenMessage = 'No screens available',
    this.emptyWindowMessage = 'No windows available',
    this.enableScreensTab = true,
    this.enableWindowsTab = true,
    this.refreshInterval = const Duration(seconds: 3),
    this.style = const ScreenSelectDialogStyle(),
    this.headerBuilder,
    this.thumbnailBuilder,
    this.actionsBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
  });

  final String title;
  final String screenTabLabel;
  final String windowTabLabel;
  final String cancelLabel;
  final String shareLabel;
  final String emptyScreenMessage;
  final String emptyWindowMessage;
  final bool enableScreensTab;
  final bool enableWindowsTab;
  final Duration refreshInterval;
  final ScreenSelectDialogStyle style;

  final ScreenSelectHeaderBuilder? headerBuilder;
  final ScreenThumbnailBuilder? thumbnailBuilder;
  final ScreenSelectActionsBuilder? actionsBuilder;
  final ScreenSelectEmptyBuilder? emptyBuilder;
  final ScreenSelectLoadingBuilder? loadingBuilder;

  @override
  ScreenSelectDialogState createState() => ScreenSelectDialogState();
}

class ScreenSelectDialogState extends State<ScreenSelectDialog>
    with SingleTickerProviderStateMixin {
  final Map<String, DesktopCapturerSource> sources = <String, DesktopCapturerSource>{};
  final List<StreamSubscription<DesktopCapturerSource>> _subscriptions = [];

  Timer? _timer;
  late TabController _tabController;
  bool _awaitingFirstFetch = true;
  bool _refreshing = false;
  bool _sideEffectsDisposed = false;
  int _lastTabIndex = 0;
  SourceType? _refreshingType;
  final Set<SourceType> _loadedTypes = <SourceType>{};

  /// True until the first [refreshSources] cycle finishes.
  @protected
  bool get awaitingFirstFetch => _awaitingFirstFetch;

  /// True while [refreshSources] is awaiting [desktopCapturer.getSources].
  @protected
  bool get refreshing => _refreshing;

  /// Currently highlighted source (may belong to another tab until user picks on this tab).
  @protected
  DesktopCapturerSource? selectedSource;

  /// After the first [refreshSources] completes, false.
  @protected
  bool initialLoad = true;

  @override
  void initState() {
    super.initState();
    final len = _effectiveTabLength;
    _tabController = TabController(length: len, vsync: this);
    _lastTabIndex = _tabController.index;
    _tabController.addListener(_onTabIndexSettled);
    _subscriptions.add(desktopCapturer.onAdded.stream.listen((source) {
      sources[source.id] = source;
      if (mounted) setState(() {});
    }));
    _subscriptions.add(desktopCapturer.onRemoved.stream.listen((source) {
      sources.remove(source.id);
      if (mounted) setState(() {});
    }));
    _subscriptions.add(desktopCapturer.onThumbnailChanged.stream.listen((source) {
      if (mounted) setState(() {});
    }));
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) refreshSources();
    });
  }

  /// If both flags are false, behave as if both are enabled (same as legacy dialog).
  bool get _misconfiguredTabs => !widget.enableScreensTab && !widget.enableWindowsTab;

  bool get _useScreensTab => widget.enableScreensTab || _misconfiguredTabs;

  bool get _useWindowsTab => widget.enableWindowsTab || _misconfiguredTabs;

  int get _effectiveTabLength {
    var n = 0;
    if (_useScreensTab) n++;
    if (_useWindowsTab) n++;
    return n;
  }

  void _onTabIndexSettled() {
    final nextIndex = _tabController.index;
    if (nextIndex != _lastTabIndex) {
      _lastTabIndex = nextIndex;
      final nextType = _sourceTypeForIndex(nextIndex);
      if (mounted) {
        setState(() {
          // Force an explicit loading state while the next tab resolves.
          _refreshing = true;
          _refreshingType = nextType;
          sources.removeWhere((_, source) => source.type == nextType);
        });
      }
    }
    if (_tabController.indexIsChanging) return;
    if (mounted) refreshSources();
  }

  @override
  void dispose() {
    if (!_sideEffectsDisposed) {
      _disposeCaptureSideEffects();
    }
    _tabController.removeListener(_onTabIndexSettled);
    _tabController.dispose();
    super.dispose();
  }

  /// Share is enabled only when a source is selected.
  @protected
  bool get canConfirm => selectedSource != null;

  /// Active capture category for the visible tab.
  @protected
  SourceType get currentTabType => _sourceTypeForIndex(_tabController.index);

  @protected
  TabController get tabController => _tabController;

  @protected
  List<DesktopCapturerSource> sourcesOfType(SourceType type) {
    return sources.values.where((s) => s.type == type).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  SourceType _sourceTypeForIndex(int i) {
    if (_useScreensTab && _useWindowsTab) {
      return i == 0 ? SourceType.Screen : SourceType.Window;
    }
    if (_useScreensTab) return SourceType.Screen;
    return SourceType.Window;
  }

  @protected
  int indexForSourceType(SourceType t) {
    if (_useScreensTab && _useWindowsTab) {
      return t == SourceType.Screen ? 0 : 1;
    }
    return 0;
  }

  @protected
  void selectSource(DesktopCapturerSource source) {
    setState(() => selectedSource = source);
  }

  @protected
  Future<void> refreshSources() async {
    if (!mounted) return;
    final requestedType = currentTabType;
    setState(() {
      _refreshing = true;
      _refreshingType = requestedType;
      sources.removeWhere((_, source) => source.type == requestedType);
    });
    try {
      final list = await desktopCapturer.getSources(types: [requestedType]);
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer.periodic(widget.refreshInterval, (_) {
        desktopCapturer.updateSources(types: [requestedType]);
      });
      sources.addEntries(list.map((e) => MapEntry(e.id, e)));
      _loadedTypes.add(requestedType);
    } catch (_) {
      // Keep dialog usable; empty state will show.
      _loadedTypes.add(requestedType);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _refreshingType = null;
          _awaitingFirstFetch = false;
          initialLoad = false;
        });
      }
    }
  }

  @protected
  bool shouldShowLoadingForType(SourceType type) {
    if (_awaitingFirstFetch) return true;
    if (!_loadedTypes.contains(type)) return true;
    return _refreshing && _refreshingType == type && sourcesOfType(type).isEmpty;
  }

  @protected
  void confirm() {
    if (!canConfirm) return;
    _disposeCaptureSideEffects();
    Navigator.of(context).pop<DesktopCapturerSource>(selectedSource);
  }

  @protected
  void cancel() {
    _disposeCaptureSideEffects();
    Navigator.of(context).pop<DesktopCapturerSource>(null);
  }

  void _disposeCaptureSideEffects() {
    if (_sideEffectsDisposed) return;
    _sideEffectsDisposed = true;
    _timer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }

  Color _resolvedBackground(BuildContext context) {
    return widget.style.backgroundColor ?? Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final maxW = (mq.width - 48).clamp(280.0, double.infinity);
    final maxH = (mq.height - 48).clamp(240.0, double.infinity);
    final w = widget.style.width.clamp(280.0, maxW);
    final h = widget.style.height.clamp(240.0, maxH);

    return Dialog(
      backgroundColor: _resolvedBackground(context),
      elevation: widget.style.elevation,
      shape: RoundedRectangleBorder(borderRadius: widget.style.borderRadius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: w,
        height: h,
        child: buildBody(context),
      ),
    );
  }

  /// Top-level layout inside the [Dialog]. Override for a completely custom shell
  /// (see [SidebarScreenSelectDialogState]).
  @protected
  Widget buildBody(BuildContext context) {
    return Padding(
      padding: widget.style.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHeader(context),
          Expanded(
            child: Padding(
              padding: widget.style.contentPadding,
              child: Column(
                children: [
                  if (_tabController.length > 1) ...[
                    buildTabs(context),
                    SizedBox(height: widget.style.gridSpacing),
                  ],
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabViewPages(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: widget.style.gridSpacing),
          buildActions(context),
        ],
      ),
    );
  }

  List<Widget> _tabViewPages(BuildContext context) {
    final pages = <Widget>[];
    if (_useScreensTab) {
      pages.add(_tabPage(context, SourceType.Screen));
    }
    if (_useWindowsTab) {
      pages.add(_tabPage(context, SourceType.Window));
    }
    return pages;
  }

  Widget _tabPage(BuildContext context, SourceType type) {
    if (shouldShowLoadingForType(type)) {
      return Center(child: buildLoading(context));
    }
    if (sourcesOfType(type).isEmpty) {
      return Center(child: buildEmpty(context, type));
    }
    return buildSourceGrid(context, type);
  }

  @protected
  Widget buildHeader(BuildContext context) {
    if (widget.headerBuilder != null) {
      return widget.headerBuilder!(context, cancel, widget.title);
    }
    final theme = Theme.of(context);
    final titleStyle = widget.style.titleStyle ?? theme.textTheme.titleLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.title, style: titleStyle),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: cancel,
          ),
        ],
      ),
    );
  }

  @protected
  Widget buildTabs(BuildContext context) {
    final theme = Theme.of(context);
    final tabStyle = widget.style.tabLabelStyle ??
        theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final tabs = <Tab>[];
    if (_useScreensTab) {
      tabs.add(Tab(child: Text(widget.screenTabLabel, style: tabStyle)));
    }
    if (_useWindowsTab) {
      tabs.add(Tab(child: Text(widget.windowTabLabel, style: tabStyle)));
    }
    return TabBar(
      controller: _tabController,
      tabs: tabs,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
    );
  }

  @protected
  Widget buildSourceGrid(BuildContext context, SourceType type) {
    final crossCount = type == SourceType.Screen ? widget.style.screenColumns : widget.style.windowColumns;
    final items = sourcesOfType(type);
    final thumbAr = widget.style.thumbnailAspectRatio;
    // Cell height ≈ thumb width/thumbAr + label row; childAspectRatio = width/height.
    final cellAspect = 1 / (1 / thumbAr + 0.28);
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: widget.style.gridSpacing,
        mainAxisSpacing: widget.style.gridSpacing,
        childAspectRatio: cellAspect,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final source = items[index];
        final sel = selectedSource?.id == source.id;
        return buildThumbnail(context, source, sel);
      },
    );
  }

  @protected
  Widget buildThumbnail(
    BuildContext context,
    DesktopCapturerSource source,
    bool selected,
  ) {
    if (widget.thumbnailBuilder != null) {
      return widget.thumbnailBuilder!(
        context,
        source,
        selected,
        () => selectSource(source),
      );
    }
    return ScreenSelectThumbnail(
      source: source,
      selected: selected,
      onTap: () => selectSource(source),
      aspectRatio: widget.style.thumbnailAspectRatio,
      borderRadius: widget.style.thumbnailBorderRadius,
      selectedBorderWidth: widget.style.selectedBorderWidth,
      selectedBorderColor: widget.style.selectedBorderColor,
      backgroundColor: widget.style.thumbnailBackground,
      labelStyle: widget.style.thumbnailLabelStyle,
      selectedLabelStyle: widget.style.selectedThumbnailLabelStyle,
    );
  }

  @protected
  Widget buildEmpty(BuildContext context, SourceType type) {
    final message = type == SourceType.Screen ? widget.emptyScreenMessage : widget.emptyWindowMessage;
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context, type, message);
    }
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          type == SourceType.Screen ? Icons.desktop_windows_outlined : Icons.window_outlined,
          size: 48,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @protected
  Widget buildLoading(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.8),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading sources...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @protected
  Widget buildActions(BuildContext context) {
    final shareEnabled = canConfirm;
    if (widget.actionsBuilder != null) {
      return widget.actionsBuilder!(context, cancel, confirm, shareEnabled);
    }
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: cancel,
          child: Text(widget.cancelLabel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: shareEnabled ? confirm : null,
          icon: const Icon(Icons.screen_share_outlined, size: 20),
          label: Text(widget.shareLabel),
          style: FilledButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
