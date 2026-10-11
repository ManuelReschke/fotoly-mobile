import 'package:flutter/material.dart';

import '../l10n/album_error_l10n.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../models/album_sharing.dart';
import '../services/pixelfox_api_client.dart';
import 'sheet_insets.dart';

typedef AlbumMemberInviteCall =
    Future<AlbumMemberInvite> Function({int? userId, String? username});

/// Invite and remove members of one owned album.
Future<void> showAlbumMembersSheet({
  required BuildContext context,
  required Future<List<AlbumMember>> Function() load,
  required AlbumMemberInviteCall invite,
  required Future<void> Function(int userId) remove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) =>
        _AlbumMembersBody(load: load, invite: invite, remove: remove),
  );
}

class _AlbumMembersBody extends StatefulWidget {
  const _AlbumMembersBody({
    required this.load,
    required this.invite,
    required this.remove,
  });

  final Future<List<AlbumMember>> Function() load;
  final AlbumMemberInviteCall invite;
  final Future<void> Function(int userId) remove;

  @override
  State<_AlbumMembersBody> createState() => _AlbumMembersBodyState();
}

class _AlbumMembersBodyState extends State<_AlbumMembersBody> {
  final TextEditingController _username = TextEditingController();
  final List<AlbumMember> _members = [];
  List<AlbumMemberCandidate> _candidates = const [];
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await widget.load();
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final s = context.l10nRead;
      setState(() {
        _loading = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumMemberLoadError,
        );
      });
    }
  }

  Future<void> _invite({int? userId, String? username}) async {
    if (_working) return;
    final s = context.l10nRead;
    if (userId == null) {
      final name = _username.text.trim();
      if (name.isEmpty) {
        setState(() => _error = s.albumUsernameRequired);
        return;
      }
      if (name.runes.length > 150) {
        setState(() => _error = s.albumUsernameTooLong);
        return;
      }
      username = name;
    }
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.invite(userId: userId, username: username);
      if (!mounted) return;
      setState(() {
        _working = false;
        _candidates = const [];
        _username.clear();
        _upsert(result.member);
        _notice = result.alreadyMember
            ? s.albumAlreadyMember
            : s.albumInviteSent;
      });
    } on AlbumMemberAmbiguousException catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _candidates = error.candidates;
        _error = s.albumMemberAmbiguous;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumMemberInviteError,
        );
      });
    }
  }

  Future<void> _remove(AlbumMember member) async {
    if (_working) return;
    final s = context.l10nRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.albumRemoveMemberTitle),
        content: Text(s.albumRemoveMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.albumRemoveMember),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.remove(member.userId);
      if (!mounted) return;
      setState(() {
        _working = false;
        _members.removeWhere((item) => item.userId == member.userId);
        _notice = s.albumMemberRemoved;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumMemberRemoveError,
        );
      });
    }
  }

  void _upsert(AlbumMember member) {
    final index = _members.indexWhere((item) => item.userId == member.userId);
    if (index >= 0) {
      _members[index] = member;
    } else {
      _members.add(member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final media = MediaQuery.of(context);
    final bottom = sheetBottomInset(context);
    final height = (media.size.height * 0.85 - bottom).clamp(
      240.0,
      media.size.height,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Text(
                s.albumMembers,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(s.albumMembersHelp),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('album-invite-username'),
                      controller: _username,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: s.albumInviteLabel,
                      ),
                      onSubmitted: (_) => _invite(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('album-invite-send'),
                    onPressed: _working ? null : () => _invite(),
                    child: Text(s.albumInviteAction),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Text(_notice!),
              ],
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final candidate in _candidates)
                  ListTile(
                    key: Key('album-member-candidate-${candidate.userId}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(candidate.username),
                    subtitle: Text('#${candidate.userId}'),
                    onTap: _working
                        ? null
                        : () => _invite(userId: candidate.userId),
                  ),
              ],
              const SizedBox(height: 8),
              Expanded(child: _memberList(s)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberList(AppStrings s) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_members.isEmpty && _error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(s.retry)),
      );
    }
    if (_members.isEmpty) {
      return Center(child: Text(s.albumMembersEmpty));
    }
    return ListView(
      children: [
        for (final member in _members)
          ListTile(
            key: Key('album-member-${member.userId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(member.username),
            subtitle: Text(
              '${s.albumMemberRoleViewer} · ${member.savedFromLink ? s.albumMemberOriginLinkSave : s.albumMemberOriginInvite}',
            ),
            trailing: IconButton(
              tooltip: s.albumRemoveMember,
              onPressed: _working ? null : () => _remove(member),
              icon: const Icon(Icons.person_remove_outlined),
            ),
          ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
