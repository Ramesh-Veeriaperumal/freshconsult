module Portal::Multilingual

  def configure_language_switcher
    return unless current_portal.multilingual?
    current_portal.language_list ||= current_account.all_portal_language_objects.inject([]) do |result,language|
      result << [language_label(language), route_name(language), nil, language_availability(language)]
      result
    end
  end

  def language_label(language)
    return language.name unless language == Language.current 
    "<span class='icon-dd-tick-dark'></span>#{language.name}".html_safe
  end

  def language_availability(language)
    classes = ""
    classes << "active" if language == Language.current
    classes << " disabled-link" if @solution_item && !@solution_item.send("#{language.to_key}_available?")
    { :class => classes } 
  end

  # This is being overridden in Support::Solution::ArticlesController
  # to generate path with pretty urls (using article title)
  def route_name(language)
    url_for(params.merge({:url_locale => language.code, :only_path => true}))
  end

end