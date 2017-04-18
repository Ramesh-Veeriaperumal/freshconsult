require 'clearbit'

clearbit_yml = YAML::load(ERB.new(File.read("#{Rails.root}/config/clearbit.yml")).result)
clearbit_tokens = clearbit_yml["clearbit"][Rails.env]
Clearbit.key = clearbit_tokens['secret_api_key']

