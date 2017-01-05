module ClamavConfig
  clamav_credential = (YAML::load_file(File.join(Rails.root, 'config', 'clamav.yml')))[Rails.env]

  TCP_HOST = clamav_credential['tcp_host']
  TCP_PORT = clamav_credential['tcp_port']
  CONNECTION_POOL_SIZE = clamav_credential['connection_pool_size']
end