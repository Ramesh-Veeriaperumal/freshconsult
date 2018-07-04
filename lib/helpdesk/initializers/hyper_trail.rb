module HyperTrail
  CONFIG = YAML.load(ERB.new(File.read("#{Rails.root}/config/hyper_trail.yml")).result)[Rails.env]
end
