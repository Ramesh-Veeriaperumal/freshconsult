tokens = YAML::load_file(File.join(Rails.root, 'config', 'ner_api.yml'))
NER_API_TOKENS = tokens[Rails.env]