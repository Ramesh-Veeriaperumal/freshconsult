module Integrations::WidgetCore
	def method_missing(meth_name, *args, &block)
    matched = /(.*)_option(=?)/.match(meth_name.to_s)
    if matched.blank?
      super
    elsif matched[2] == "="
      input_key = matched[1]
      self.options = {} if self.options.blank?
      self.options[input_key] = args[0]
    else
      input_key = matched[1]
      self.options[input_key] unless self.options.blank?
    end
  end

  def respond_to?(method, include_private = false)
    matched = /(.*)_option(=?)/.match(method.to_s)
    if matched.blank?
      super
    else
      true
    end
  end

end