tokens = YAML.load_file(Rails.root.join('config', 'product_feedback.yml').to_path)
PRODUCT_FEEDBACK_CONFIG = tokens[Rails.env]
