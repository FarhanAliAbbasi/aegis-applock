import 'dart:convert';

class SecurityQuestion {
  final String id;
  final String question;
  final String answerHash;
  final String salt;

  const SecurityQuestion({
    required this.id,
    required this.question,
    required this.answerHash,
    required this.salt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'hash': answerHash,
      'salt': salt,
    };
  }

  factory SecurityQuestion.fromMap(Map<String, dynamic> map) {
    return SecurityQuestion(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      answerHash: map['hash'] as String? ?? '',
      salt: map['salt'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SecurityQuestion.fromJson(String source) =>
      SecurityQuestion.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<String> get presetQuestions => [
        'What was the name of your first school?',
        'What is your best friend\'s name?',
      ];
}
