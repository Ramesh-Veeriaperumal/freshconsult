class Account < ActiveRecord::Base
  
  def multilingual?
    self.features_included?(:multi_language) && self.launched?(:translate_solutions)
  end
  
  def applicable_languages
    @multilingual_applicable_languages ||= (supported_languages.collect do |lang|
      obj = Language.find_by_code(lang)
      obj.to_key if obj
    end).compact
  end
end