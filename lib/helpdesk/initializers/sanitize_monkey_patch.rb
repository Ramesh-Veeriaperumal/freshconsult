# For parity, we expect CSS NOT to be sanitised
#TODO Revisit and introduce whitelist with benchmarking done properly
Sanitize::Transformers::CSS::CleanAttribute.class_eval do
  def call(*args)
  end
end
