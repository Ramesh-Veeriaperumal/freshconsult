class CustomFieldDecorator < SimpleDelegator
  class << self
    def utc_format(cf)
      cf.each_pair { |k, v| cf[k] = v.utc if v.respond_to?(:utc) }
      cf
    end
  end
end
