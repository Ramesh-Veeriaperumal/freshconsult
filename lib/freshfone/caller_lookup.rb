module Freshfone::CallerLookup

  STRANGE_NUMBERS = {
    :"7378742833" => "RESTRICTED",
    :"2562533" => "BLOCKED",
    :"8656696" => "UNKNOWN",
    :"266696687" => "ANONYMOUS"
  }
  
  def remove_country_code(number)
      num_helper = number.gsub(/\D/, '')
      num_helper.starts_with?("1") ? num_helper[1, num_helper.length-1] : num_helper
  end

  def strange_number?(number)
    number_formatted = remove_country_code(number)
    STRANGE_NUMBERS.has_key?(number_formatted.to_sym)
  end

  def strange_number_lookup(number)
    number_formatted = remove_country_code(number)
    STRANGE_NUMBERS[number_formatted.to_sym]
  end

  def caller_lookup(number, user_contact = nil)
    if user_contact.present?
      number = user_contact.name
    else
      number = strange_number_lookup(number) || number
    end
    number
  end
  
  def strange_number_class(number)
    strange_number?(number) ? 'strikethrough' : ''
  end

  def strange_number_strikethrough(number, class_name)
    content_tag(:span, number,{:class => "strikethrough #{class_name}"})
  end

end