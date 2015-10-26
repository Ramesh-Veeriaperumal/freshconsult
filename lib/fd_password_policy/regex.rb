module FDPasswordPolicy
  module Regex

    include FDPasswordPolicy::Constants
    
    def self.alphanumeric
      ALPHANUMERIC_REGEX
    end

    def self.mixed_case
      MIXED_CASE_REGEX
    end

    def self.special_characters
      SPECIAL_CHARACTERS_REGEX
    end
    
  end
end