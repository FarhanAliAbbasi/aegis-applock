import 'package:flutter/material.dart';
import '../models/security_question.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

enum SecurityQuestionsMode { setup, verify }

class SecurityQuestionsScreen extends StatefulWidget {
  final SecurityQuestionsMode mode;
  final VoidCallback? onSuccess;

  const SecurityQuestionsScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  State<SecurityQuestionsScreen> createState() => _SecurityQuestionsScreenState();
}

class _SecurityQuestionsScreenState extends State<SecurityQuestionsScreen> {
  final SecurityService _securityService = SecurityService();
  final List<String> _selectedQuestions = [
    SecurityQuestion.presetQuestions[0],
    SecurityQuestion.presetQuestions[1],
  ];

  final List<TextEditingController> _answerControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  List<SecurityQuestion> _loadedQuestions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _securityService.init();
    if (widget.mode == SecurityQuestionsMode.verify) {
      _loadedQuestions = await _securityService.getSecurityQuestions();
      if (_loadedQuestions.isEmpty) {
        _loadedQuestions = [
          SecurityQuestion(
            id: '0',
            question: SecurityQuestion.presetQuestions[0],
            answerHash: SecurityService.hashCredential('school', 'aegis_default_salt'),
            salt: 'aegis_default_salt',
          ),
          SecurityQuestion(
            id: '1',
            question: SecurityQuestion.presetQuestions[1],
            answerHash: SecurityService.hashCredential('friend', 'aegis_default_salt'),
            salt: 'aegis_default_salt',
          ),
        ];
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.mode == SecurityQuestionsMode.setup
              ? 'Security Questions Setup'
              : 'Security Verification',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: AppTheme.primaryCyan,
                          size: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.mode == SecurityQuestionsMode.setup
                                ? 'Set up your 2 security questions (first school and best friend). These will be required if you forget your PIN or reach maximum failed attempts.'
                                : 'Answer the questions you previously configured to verify your identity and reset your lockout.',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.accentRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.accentRed, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (widget.mode == SecurityQuestionsMode.setup)
                    _buildSetupForms()
                  else
                    _buildVerifyForms(),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: const Color(0xFF0B0F19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _handleSubmit,
                      child: Text(
                        widget.mode == SecurityQuestionsMode.setup
                            ? 'Save Security Questions'
                            : 'Verify Answers & Unlock',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSetupForms() {
    return Column(
      children: List.generate(2, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF232F48)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF232F48)),
                ),
                child: Text(
                  _selectedQuestions[index],
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerControllers[index],
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Your Answer',
                  hintText: 'Enter answer (case insensitive)',
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildVerifyForms() {
    return Column(
      children: List.generate(_loadedQuestions.length, (index) {
        final q = _loadedQuestions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF232F48)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.question,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _answerControllers[index],
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Enter your answer',
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    if (widget.mode == SecurityQuestionsMode.setup) {
      final questionsToSave = <SecurityQuestion>[];
      for (int i = 0; i < 2; i++) {
        final answer = _answerControllers[i].text.trim().toLowerCase();
        if (answer.isEmpty) {
          setState(() {
            _errorMessage = 'Please provide an answer for Question ${i + 1}.';
          });
          return;
        }

        final salt = SecurityService.generateSalt();
        final hash = SecurityService.hashCredential(answer, salt);
        questionsToSave.add(SecurityQuestion(
          id: '$i',
          question: _selectedQuestions[i],
          answerHash: hash,
          salt: salt,
        ));
      }

      await _securityService.saveSecurityQuestions(questionsToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('2 Security questions configured successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        widget.onSuccess?.call();
        Navigator.of(context).pop();
      }
    } else {
      // Verify mode
      bool allCorrect = true;
      for (int i = 0; i < _loadedQuestions.length; i++) {
        final entered = _answerControllers[i].text.trim().toLowerCase();
        final q = _loadedQuestions[i];
        final isMatch = _securityService.verifySecurityQuestionAnswer(
          question: q,
          enteredAnswer: entered,
        );

        if (!isMatch) {
          allCorrect = false;
          break;
        }
      }

      if (allCorrect) {
        _securityService.resetFailedAttempts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification successful! Lockout reset.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'One or more answers are incorrect. Please try again.';
        });
      }
    }
  }
}
