class CustomFieldDecorator < SimpleDelegator
  class << self
    def without_cf(name)
      "#{name[3..-1]}"
    end

    def name_mapping(fields)
      fields.each_with_object({}) { |cf, hash| hash[cf.name.to_sym] = CustomFieldDecorator.without_cf(cf.name).to_sym }
    end
  end
end
