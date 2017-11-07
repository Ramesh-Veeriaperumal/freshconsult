class CustomFieldDecorator < BaseDelegator
  class << self
    def display_name(name)
      (name[3..-1]).to_s
    end

    def name_mapping(fields)
      fields.each_with_object({}) { |cf, hash| hash[cf.name] = CustomFieldDecorator.display_name(cf.name) }
    end

    def custom_field?(field)
      field.ends_with?("_#{Account.current.id}")
    end
  end
end
