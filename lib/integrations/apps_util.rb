require 'openssl'
require 'base64'

module Integrations::AppsUtil
  def get_installed_apps
    @installed_applications = Integrations::InstalledApplication.find(:all, :conditions => ["account_id = ?", current_account])
  end

  def execute(clazz_str, method_str, args=[])
    unless clazz_str.blank?
      obj = clazz_str.constantize
      obj = obj.new unless obj.respond_to?(method_str)
      if obj.respond_to?(method_str)
        obj.send(method_str, args)
      else
        raise "#{clazz_str} is not responding to #{method_str}."
      end
    end
  end

  def replace_liquid_values(liquid_template, data)
    if liquid_template.class == Hash
      liquid_template.map {|key, value| liquid_template[key] = replace_liquid_values(value, data)}
    elsif liquid_template.class == Array
      liquid_template.each_index {|i| liquid_template[i] = replace_liquid_values(liquid_template[i], data)}
    elsif liquid_template.class == String
      data = data.attributes if data.respond_to? :attributes
      Liquid::Template.parse(liquid_template).render(data)
    end
  end
end
