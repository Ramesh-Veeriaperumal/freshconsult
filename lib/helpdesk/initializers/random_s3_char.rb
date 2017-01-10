config = YAML::load(ERB.new(File.read("#{Rails.root}/config/random_s3_char.yml")).result)

RANDOM_S3_CHAR_CONFIG = (config[Rails.env] || config).symbolize_keys