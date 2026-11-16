import '../../core/constants/ai_providers_constants.dart';

class AIProviderModel {
  final String id;
  final String name;
  final String providerType; // 'gemini', 'openai', 'deepseek', 'openrouter', 'groq', 'custom'
  final String modelName;
  final String apiKey;
  final String? baseUrl;
  final bool isActive;
  final bool isPredefined;
  final List<String> customModels;

  const AIProviderModel({
    required this.id,
    required this.name,
    required this.providerType,
    required this.modelName,
    required this.apiKey,
    this.baseUrl,
    this.isActive = false,
    this.isPredefined = false,
    this.customModels = const [],
  });

  List<String> get allModels {
    final defaults = AIProvidersConstants.getDefaultModelsForType(providerType);
    final combined = <String>{...defaults, ...customModels};
    if (modelName.isNotEmpty) combined.add(modelName);
    return combined.toList();
  }

  String get assetLogo {
    switch (providerType.toLowerCase()) {
      case 'gemini':
        return 'assets/gemini.webp';
      case 'openrouter':
        return 'assets/oepnrouter.png';
      case 'openai':
        return 'assets/gpt.webp';
      case 'deepseek':
        return 'assets/deepseek.png';
      case 'groq':
        return 'assets/groq.png';
      case 'ollama':
      case 'custom':
      default:
        return 'assets/ollama.webp';
    }
  }

  AIProviderModel copyWith({
    String? id,
    String? name,
    String? providerType,
    String? modelName,
    String? apiKey,
    String? baseUrl,
    bool? isActive,
    bool? isPredefined,
    List<String>? customModels,
  }) {
    return AIProviderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      modelName: modelName ?? this.modelName,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      isActive: isActive ?? this.isActive,
      isPredefined: isPredefined ?? this.isPredefined,
      customModels: customModels ?? this.customModels,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'provider_type': providerType,
        'model_name': modelName,
        'api_key': apiKey,
        'base_url': baseUrl,
        'is_active': isActive ? 1 : 0,
        'is_predefined': isPredefined ? 1 : 0,
        'custom_models': customModels.join(','),
      };

  factory AIProviderModel.fromMap(Map<String, dynamic> map) {
    final rawCustom = (map['custom_models'] ?? map['customModels']) as String? ?? '';
    final customList = rawCustom
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return AIProviderModel(
      id: map['id'] as String,
      name: map['name'] as String,
      providerType: (map['provider_type'] ?? map['providerType']) as String,
      modelName: (map['model_name'] ?? map['modelName']) as String,
      apiKey: (map['api_key'] ?? map['apiKey']) as String? ?? '',
      baseUrl: (map['base_url'] ?? map['baseUrl']) as String?,
      isActive: (map['is_active'] ?? map['isActive']) == 1,
      isPredefined: (map['is_predefined'] ?? map['isPredefined']) == 1,
      customModels: customList,
    );
  }
}

