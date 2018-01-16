BOT_CONFIG = YAML.load_file(Rails.root.join('config', 'bot.yml'))[Rails.env].symbolize_keys!
BOT_JWT_SECRET = BOT_CONFIG[:jwt_secret]
BOT_JWE_SECRET = BOT_CONFIG[:jwe_secret]
