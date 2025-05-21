import 'package:flutter/material.dart';
import 'package:trip_planner/auth/auth_service.dart';
import 'package:trip_planner/widgets/base/profile_picture.dart';

class UserSearchField extends StatefulWidget {
  final void Function(Map<String, dynamic>) onUserSelected;
  final String labelText;
  final String hintText;

  const UserSearchField({
    super.key,
    required this.onUserSelected,
    this.labelText = 'Find User by @username',
    this.hintText = 'Enter @ followed by username',
  });

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  final _controller = TextEditingController();
  final _authService = AuthService();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleSearchInput);
    _focusNode.addListener(() {
      setState(() {
        _showResults = _focusNode.hasFocus && _controller.text.isNotEmpty;
      });
    });
  }

  void _handleSearchInput() {
    final text = _controller.text;
    if (text.isNotEmpty && !text.startsWith('@')) {
      _controller.text = '@' + text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    if (text.startsWith('@') && text.length > 1) {
      _performSearch(text.substring(1));
    } else {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _authService.searchUsersByUsername(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _showResults = results.isNotEmpty && _focusNode.hasFocus;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    _controller.text = '@${user['username']}';
    widget.onUserSelected(user);
    setState(() {
      _showResults = false;
      _controller.clear(); // Automatically clear the search field
    });
    _focusNode.unfocus();
  }

  bool _isValidHttpUrl(dynamic url) {
    if (url == null) return false;
    final s = url.toString();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  String? _getProfilePictureUrl(Map<String, dynamic> user) {
    // Try common keys for Firebase Storage URLs
    if (_isValidHttpUrl(user['profilePictureUrl']))
      return user['profilePictureUrl'];
    if (_isValidHttpUrl(user['photoURL'])) return user['photoURL'];
    if (_isValidHttpUrl(user['photoUrl'])) return user['photoUrl'];
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.dividerColor),
      borderRadius: BorderRadius.circular(8.0),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: theme.primaryColor, width: 2.0),
      borderRadius: BorderRadius.circular(8.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.person_add),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedInputBorder,
            suffixIcon:
                _isSearching
                    ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(8),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                    : (_controller.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _showResults = false;
                            });
                          },
                        )
                        : null),
          ),
        ),
        if (_showResults) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: ProfilePictureWidget(
                    photoUrl: _getProfilePictureUrl(user),
                    username: user['username'],
                    size: 40,
                  ),
                  title: Text('@${user['username']}'),
                  subtitle: Text(user['email'] ?? ''),
                  onTap: () => _selectUser(user),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
