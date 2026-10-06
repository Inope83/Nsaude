import 'package:flutter/material.dart';

import '../../features/geography/geography_repository.dart';
import '../l10n/app_strings.dart';
import '../theme/app_spacing.dart';

class CascadingLocationPicker extends StatefulWidget {
  const CascadingLocationPicker({
    super.key,
    required this.geographyService,
    required this.onSucoChanged,
    this.errorText,
  });

  final GeographyService geographyService;
  final ValueChanged<GeoItem?> onSucoChanged;
  final String? errorText;

  @override
  State<CascadingLocationPicker> createState() => _CascadingLocationPickerState();
}

class _CascadingLocationPickerState extends State<CascadingLocationPicker> {
  List<GeoItem> _municipalities = const <GeoItem>[];
  List<GeoItem> _posts = const <GeoItem>[];
  List<GeoItem> _sucos = const <GeoItem>[];
  GeoItem? _municipality;
  GeoItem? _post;
  GeoItem? _suco;
  bool _loadingMunicipalities = true;
  bool _loadingPosts = false;
  bool _loadingSucos = false;

  @override
  void initState() {
    super.initState();
    _loadMunicipalities();
  }

  Future<void> _loadMunicipalities() async {
    try {
      final items = await widget.geographyService.municipalities();
      if (!mounted) return;
      setState(() {
        _municipalities = items;
        _loadingMunicipalities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMunicipalities = false);
    }
  }

  Future<void> _loadPosts(String municipalityCode) async {
    try {
      final items = await widget.geographyService.postsFor(municipalityCode);
      if (!mounted) return;
      setState(() {
        _posts = items;
        _loadingPosts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadSucos(String administrativePostCode) async {
    try {
      final items = await widget.geographyService.sucosFor(administrativePostCode);
      if (!mounted) return;
      setState(() {
        _sucos = items;
        _loadingSucos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSucos = false);
    }
  }

  void _onMunicipalityChanged(GeoItem? value) {
    setState(() {
      _municipality = value;
      _posts = const <GeoItem>[];
      _post = null;
      _sucos = const <GeoItem>[];
      _suco = null;
      _loadingPosts = value != null;
      _loadingSucos = false;
    });
    widget.onSucoChanged(null);
    if (value != null) {
      _loadPosts(value.code);
    }
  }

  void _onPostChanged(GeoItem? value) {
    setState(() {
      _post = value;
      _sucos = const <GeoItem>[];
      _suco = null;
      _loadingSucos = value != null;
    });
    widget.onSucoChanged(null);
    if (value != null) {
      _loadSucos(value.code);
    }
  }

  void _onSucoChanged(GeoItem? value) {
    setState(() => _suco = value);
    widget.onSucoChanged(value);
  }

  List<DropdownMenuItem<GeoItem>> _items(List<GeoItem> values) => [
        for (final value in values)
          DropdownMenuItem<GeoItem>(value: value, child: Text(value.name)),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsEnabled =
        !_loadingPosts && _municipality != null && _posts.isNotEmpty;
    final sucoEnabled = !_loadingSucos && _post != null && _sucos.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.locationPickerHint,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.s8),
        DropdownButtonFormField<GeoItem>(
          initialValue: _municipality,
          items: _loadingMunicipalities ? const [] : _items(_municipalities),
          onChanged: _loadingMunicipalities ? null : _onMunicipalityChanged,
          decoration: const InputDecoration(labelText: AppStrings.municipality),
        ),
        const SizedBox(height: AppSpacing.s16),
        DropdownButtonFormField<GeoItem>(
          initialValue: _post,
          items: _items(_posts),
          onChanged: postsEnabled ? _onPostChanged : null,
          decoration: const InputDecoration(labelText: AppStrings.adminPost),
        ),
        const SizedBox(height: AppSpacing.s16),
        DropdownButtonFormField<GeoItem>(
          initialValue: _suco,
          items: _items(_sucos),
          onChanged: sucoEnabled ? _onSucoChanged : null,
          forceErrorText: widget.errorText,
          decoration: const InputDecoration(labelText: AppStrings.suco),
        ),
      ],
    );
  }
}
