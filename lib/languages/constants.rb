module Languages::Constants
  AVAILABLE_LOCALES_WITH_ID = YAML.load_file(Rails.root.join('config', 'languages.yml'))

  LANGUAGE_ALT_CODE = {
    :ja => 'ja-JP',
    :nb => 'nb-NO',
    :no => 'nb-NO',
    :pt => 'pt-PT',
    :ru => 'ru-RU',
    :sv => 'sv-SE',
    :'zh-TW' => 'zh-CN'
  }.with_indifferent_access.freeze

  ANALYTICS_LANG_CODES = {
    'ja-JP': 'ja',
    'lv-LV': 'lv',
    'nb-NO': 'no',
    'ru-RU': 'ru',
    'es-LA': 'es-419',
    'sv-SE': 'sv'
  }.freeze
end
