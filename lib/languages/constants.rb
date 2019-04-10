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
end
