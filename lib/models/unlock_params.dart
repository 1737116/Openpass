
class UnlockParams {
  final String filePath;
  final String password;
  final String? keyData;

  UnlockParams({
    required this.filePath,
    required this.password,
    this.keyData,
  });
}