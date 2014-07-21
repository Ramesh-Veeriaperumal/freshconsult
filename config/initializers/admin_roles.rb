config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/admin_roles.yml")).result)
ADMIN_ROLES_LIST = config.symbolize_keys