class PrivilegesUtil
  include Authority::FreshdeskRails::ModelHelpers
  attr_accessor :privileges

  def [](attr_name)
    safe_send(attr_name.to_s)
  end

  def []=(attr_name, value)
    safe_send("#{attr_name}=", value)
  end
end
