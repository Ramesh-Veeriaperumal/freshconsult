SandboxConfig = YAML.load_file(File.join(Rails.root, 'config', 'sandbox.yml'))[Rails.env]

SANDBOX_REPO_URL    = SandboxConfig['repo_url']
SANDBOX_PUBLIC_KEY  = SandboxConfig['public_key']
SANDBOX_PRIVATE_KEY = SandboxConfig['private_key']
SANDBOX_USERNAME    = SandboxConfig['username']