fluffy_config = YAML::load_file(File.join(Rails.root, 'config', 'fluffy.yml'))[Rails.env]

Fluffy.configure do |config|
  config.host = fluffy_config["host"]
  config.username = fluffy_config["username"]
  config.password = fluffy_config["password"]
end

$fluffy_client = Fluffy::AccountsApi.new