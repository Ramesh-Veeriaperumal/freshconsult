config = YAML::load_file(File.join(Rails.root, 'config', 'thrift.yml'))[Rails.env]
ACTIVITIES_ENABLED = !Rails.env.development? && !Rails.env.test?
if ACTIVITIES_ENABLED
  $thrift_server_port = config["port"]

  $activities_thrift_server_ip   = config["activities"]["host"]
  $activities_thrift_socket      = Thrift::Socket.new($activities_thrift_server_ip, $thrift_server_port)
  $activities_thrift_transport   = Thrift::BufferedTransport.new($activities_thrift_socket)
  $activities_thrift_protocol    = Thrift::BinaryProtocol.new($activities_thrift_transport)

  $activities_export_thrift_server_ip   = config["activities_export"]["host"]
  $activities_export_thrift_socket      = Thrift::Socket.new($activities_export_thrift_server_ip, $thrift_server_port)
  $activities_export_thrift_transport   = Thrift::BufferedTransport.new($activities_export_thrift_socket)
  $activities_export_thrift_protocol    = Thrift::BinaryProtocol.new($activities_export_thrift_transport)

  #$thrift_transport.open()
end