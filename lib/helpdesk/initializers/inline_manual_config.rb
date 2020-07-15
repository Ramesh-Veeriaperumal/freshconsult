tokens = YAML::load_file(File.join(Rails.root, 'config', 'inline_manual.yml'))
INLINE_MANUAL_TOKENS = tokens["inline_manual"][Rails.env]