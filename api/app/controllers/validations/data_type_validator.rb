class DataTypeValidator < ActiveModel::Validator
  def validate(record)
    options[:rules].each_pair do |type, fields|
      fields.each do |field|
        record.errors[field.to_sym] << "is not a/an #{type}" unless valid_type?(type, record.send(field))
      end
    end
  end

  private

    def valid_type?(type, value)
      value.class.to_s == type
    end
end
