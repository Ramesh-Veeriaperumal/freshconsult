Infra = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

if Infra['SUPPORT_LAYER']
  Helpkit::Application.configure do
    #Inserting multilingual middleware only for the support instances
    config.middleware.insert_after 'Middleware::TrustedIp', 'Middleware::MultilingualSolutionRouter'

  end
end