module Freshfone::CallerLookup
  include Freshfone::NumberValidator

  STRANGE_NUMBERS = {
    :"7378742833"  => 'RESTRICTED',
    :"2562533"     => 'BLOCKED',
    :"8656696"     => 'UNKNOWN',
    :"266696687"   => 'ANONYMOUS',
    :"86282452253" => 'UNAVAILABLE',
    :""            => 'UNKNOWN'
  }

  UNAUTHORISED_NUMBERS_LIST = ['2024558888', '4086104900', '4153660260']
  
  
  def remove_country_code(number)
    number.gsub(/^\+1|\D/, '') #removing phone numbers starting with +1 or non digits
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

  def empty_number?(number)
    Rails.logger.info "Empty Number Check #{number}"
    number == "+"
  end

  def invalid_number?(number)
    Rails.logger.info "Invalid Number Check #{number}"
    fetch_country_code(number).blank?
  end

  def browser_caller_id(number)
    return "+#{STRANGE_NUMBERS.invert['ANONYMOUS'].to_s}" if empty_number?(number)
    number
  end
end