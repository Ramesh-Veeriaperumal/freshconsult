class Account < ActiveRecord::Base
  
  def multilingual?
    @is_multilingual ||= multilingual_available? &&
        features_included?(:enable_multilingual)  &&
        supported_languages.present?
  end

  def multilingual_available?
    @is_multilingual_available ||= launched?(:translate_solutions) && features_included?(:multi_language)
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
    @language_object ||= Language.find_by_code(language)
  end

  def supported_languages_objects
    @supported_languages_objects ||= supported_languages.map { |l| Language.find_by_code(l) }
  end

  def all_language_ids
    @all_language_ids ||= [language_object.id] + applicable_language_ids
  end

  def all_language_objects
    @all_language_objects ||= [language_object] + supported_languages_objects
  end

  def portal_languages_objects
    @portal_languages_objects ||= (portal_languages || []).map { |l| Language.find_by_code(l) }
  end

  def all_portal_language_objects
    @all_portal_language_objects ||= [language_object] + portal_languages_objects
  end
end