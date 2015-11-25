class CustomFieldDecorator < SimpleDelegator
  class << self
    def utc_format(cf)
      cf.each_pair { |k, v| cf[k] = v.utc if v.respond_to?(:utc) }
      cf
    end

    def remove_prepended_text_from_custom_fields(custom_fields)
      # Removing chanracters from String - https://stackoverflow.com/questions/3614389/what-is-the-easiest-way-to-remove-the-first-character-from-a-string
      custom_fields.keys.each { | key | custom_fields[key.to_s[3..-1]] = custom_fields.delete key} if custom_fields
      custom_fields
    end

    def remove_appended_text_from_ticket_fields(custom_fields)
      custom_fields.keys.each { | key | custom_fields[key.to_s[0..(-Account.current.id_length-2)]] = custom_fields.delete key} if custom_fields
      custom_fields
    end
  end
end
