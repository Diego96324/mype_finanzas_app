import 'package:equatable/equatable.dart';

enum FocusTarget { categoria, monto, notas, etiquetas, none }

class TransactionFormState extends Equatable {
  final int? selectedCategoryId;
  final bool isCategoryAutofilled;
  final FocusTarget focusTarget;
  final double? amount;
  final String notes;
  final List<String> tags;
  final bool isEditing;

  const TransactionFormState({
    this.selectedCategoryId,
    this.isCategoryAutofilled = false,
    this.focusTarget = FocusTarget.none,
    this.amount,
    this.notes = '',
    this.tags = const [],
    this.isEditing = false,
  });

  factory TransactionFormState.initial({bool isEditing = false}) => TransactionFormState(isEditing: isEditing);

  TransactionFormState copyWith({
    int? selectedCategoryId,
    bool? isCategoryAutofilled,
    FocusTarget? focusTarget,
    double? amount,
    String? notes,
    List<String>? tags,
    bool? isEditing,
  }) {
    return TransactionFormState(
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      isCategoryAutofilled: isCategoryAutofilled ?? this.isCategoryAutofilled,
      focusTarget: focusTarget ?? this.focusTarget,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  @override
  List<Object?> get props => [selectedCategoryId, isCategoryAutofilled, focusTarget, amount, notes, tags, isEditing];
}
