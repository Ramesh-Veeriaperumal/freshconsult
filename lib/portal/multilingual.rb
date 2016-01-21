module Portal::Multilingual

  def configure_language_switcher
    return unless current_portal.multilingual?
    current_portal.language_list ||= current_account.all_portal_language_objects.inject([]) do |result,language|
      result << [language.name, route_name(language), nil, language_availability(language)] unless language == Language.current
      result
    end
  end

  def language_availability(language)
    { :class => 'disabled-link' } if @solution_item && !@solution_item.send("#{language.to_key}_available?")
  end

  # This is being overridden in Support::Solution::ArticlesController
  # to generate path with pretty urls (using article title)
  def route_name(language)
    url_for(params.merge({:url_locale => language.code, :only_path => true}))
  end

end