class Sanitize
  module Config
    ADDITIONAL_DEFAULT_CONFIG = {
      whitespace_elements: {
        'td' => { before: ' ', after: ' ' } 
      }.merge(DEFAULT[:whitespace_elements])
    }
  end
end
