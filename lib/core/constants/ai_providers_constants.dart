class AIProviderPreset {
  final String id;
  final String name;
  final String providerType; // 'gemini', 'openai', 'deepseek', 'openrouter', 'groq', 'custom'
  final String? defaultBaseUrl;
  final List<String> defaultModels;
  final String defaultModel;
  final String description;
  final String apiKeyHelpUrl;

  const AIProviderPreset({
    required this.id,
    required this.name,
    required this.providerType,
    this.defaultBaseUrl,
    required this.defaultModels,
    required this.defaultModel,
    required this.description,
    required this.apiKeyHelpUrl,
  });
}

abstract final class AIProvidersConstants {
  static const String geminiId = 'provider_gemini';
  static const String openrouterId = 'provider_openrouter';
  static const String openaiId = 'provider_openai';
  static const String deepseekId = 'provider_deepseek';
  static const String groqId = 'provider_groq';

  static const List<AIProviderPreset> presets = [
    // 1. Google Gemini
    AIProviderPreset(
      id: geminiId,
      name: 'Google Gemini',
      providerType: 'gemini',
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      defaultModels: [
        'gemini-1.5-flash',
        'gemini-2.5-flash',
        'gemini-1.5-pro',
        'gemini-2.0-flash',
      ],
      defaultModel: 'gemini-1.5-flash',
      description: 'Hızlı, güçlü ve yüksek kotalı resmi Google modeli.',
      apiKeyHelpUrl: 'https://aistudio.google.com/apikey',
    ),

    // 2. OpenRouter
    AIProviderPreset(
      id: openrouterId,
      name: 'OpenRouter',
      providerType: 'openrouter',
      defaultBaseUrl: 'https://openrouter.ai/api/v1/chat/completions',
      defaultModels: [
        'deepseek/deepseek-chat',
        'google/gemini-2.0-flash-001',
        'meta-llama/llama-3.3-70b-instruct',
        'anthropic/claude-3.5-sonnet',
        'openai/gpt-4o-mini',
      ],
      defaultModel: 'deepseek/deepseek-chat',
      description: 'DeepSeek, Claude, Llama ve OpenAI dahil yüzlerce modeli tek API ile sunar.',
      apiKeyHelpUrl: 'https://openrouter.ai/keys',
    ),

    // 3. OpenAI (ChatGPT)
    AIProviderPreset(
      id: openaiId,
      name: 'OpenAI (ChatGPT)',
      providerType: 'openai',
      defaultBaseUrl: 'https://api.openai.com/v1/chat/completions',
      defaultModels: [
        'gpt-4o-mini',
        'gpt-4o',
        'o3-mini',
      ],
      defaultModel: 'gpt-4o-mini',
      description: 'Resmi OpenAI ChatGPT modelleri.',
      apiKeyHelpUrl: 'https://platform.openai.com/api-keys',
    ),

    // 4. DeepSeek
    AIProviderPreset(
      id: deepseekId,
      name: 'DeepSeek',
      providerType: 'deepseek',
      defaultBaseUrl: 'https://api.deepseek.com/chat/completions',
      defaultModels: [
        'deepseek-chat',
        'deepseek-reasoner',
      ],
      defaultModel: 'deepseek-chat',
      description: 'Gelişmiş akıl yürütme ve son derece uygun maliyetli DeepSeek modelleri.',
      apiKeyHelpUrl: 'https://platform.deepseek.com/api_keys',
    ),

    // 5. Groq
    AIProviderPreset(
      id: groqId,
      name: 'Groq (Llama & Mistral)',
      providerType: 'groq',
      defaultBaseUrl: 'https://api.groq.com/openai/v1/chat/completions',
      defaultModels: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'mixtral-8x7b-32768',
      ],
      defaultModel: 'llama-3.3-70b-versatile',
      description: 'Saniyede yüzlerce token üreten ultra hızlı Llama modelleri.',
      apiKeyHelpUrl: 'https://console.groq.com/keys',
    ),
  ];

  static List<String> getDefaultModelsForType(String providerType) {
    final preset = presets.where((p) => p.providerType == providerType).firstOrNull;
    if (preset != null) return preset.defaultModels;
    return ['gpt-4o-mini', 'gpt-4o', 'llama-3'];
  }

  static AIProviderPreset? getPresetById(String id) {
    return presets.where((p) => p.id == id).firstOrNull;
  }

  static AIProviderPreset? getPresetByType(String type) {
    return presets.where((p) => p.providerType == type).firstOrNull;
  }
}

