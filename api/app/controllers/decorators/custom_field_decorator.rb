class CustomFieldDecorator < SimpleDelegator
  class << self
    def display_name(name)
      "#{name[3..-1]}"
    end

    def name_mapping(fields)
      fields.each_with_object({}) { |cf, hash| hash[cf.name] = CustomFieldDecorator.display_name(cf.name) }
    end
  end
end
