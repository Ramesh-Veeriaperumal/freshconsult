tokens = YAML::load_file(File.join(Rails.root, 'config', 'inline_manual.yml'))
INLINE_MANUAL_TOKENS = tokens[Rails.env]["inline_manual"]