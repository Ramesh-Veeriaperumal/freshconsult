config = YAML::load_file(File.join(Rails.root, 'config', 'thrift.yml'))[Rails.env]
ACTIVITIES_ENABLED = !Rails.env.development? && !Rails.env.test?
if ACTIVITIES_ENABLED
  $thrift_server_ip   = config["host"]
  $thrift_server_port = config["port"]
  $thrift_socket      = Thrift::Socket.new($thrift_server_ip,$thrift_server_port)
  $thrift_transport   = Thrift::BufferedTransport.new($thrift_socket)
  $thrift_protocol    = Thrift::BinaryProtocol.new($thrift_transport)
  #$thrift_transport.open()
end