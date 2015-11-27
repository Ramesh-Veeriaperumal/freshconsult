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

  def applicable_language_ids
    @multilingual_applicable_languages ||= (supported_languages.collect do |lang|
      obj = Language.find_by_code(lang)
      obj.id if obj
    end).compact
  end

  def language_object
    Language.find_by_code(language)
  end

  def supported_languages_objects
    supported_languages.map { |l| Language.find_by_code(l) }
  end

  def all_language_ids
    applicable_language_ids + [language_object.id]
  end
end