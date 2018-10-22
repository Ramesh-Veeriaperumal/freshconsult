SandboxConfig = YAML.load_file(File.join(Rails.root, 'config', 'sandbox.yml'))[Rails.env]

SANDBOX_REPO_URL    = SandboxConfig['repo_url']
SANDBOX_PUBLIC_KEY  = SandboxConfig['public_key']
SANDBOX_PRIVATE_KEY = SandboxConfig['private_key']
SANDBOX_USERNAME    = SandboxConfig['username']
SANDBOX_ASSETS      = SandboxConfig['sandbox_assets']

SANDBOX_FIXTURES = YAML::load_file(File.join(Rails.root, 'config', 'sandbox_fixtures.yml')).deep_symbolize_keys[:fixtures]

MODEL_DEPENDENCIES = YAML::load_file(File.join(Rails.root, 'config', 'sandbox_config.yml'))["MODEL_DEPENDENCIES"]

SANDBOX_ID_OFFSET = YAML::load_file(File.join(Rails.root, 'config', 'sandbox_id_offset.yml'))[Rails.env][PodConfig["CURRENT_POD"]]

SANDBOX_SHARD_CONFIG = YAML::load_file(File.join(Rails.root, 'config', 'sandbox_shard_config.yml'))[Rails.env][PodConfig["CURRENT_POD"]]
