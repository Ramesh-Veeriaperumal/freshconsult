class ApiContactFieldsDecorator < SimpleDelegator
  def contact_field_choices
    case self.field_type.to_s
    when 'default_language', 'default_time_zone'
      self.choices.map { |x| x.values.reverse }.to_h
    when 'custom_dropdown' # not_tested
      self.choices.map { |x| x[:value] }
    else
      []
    end
  end

  def default_contact_field?
    self.column_name == 'default'
  end
end