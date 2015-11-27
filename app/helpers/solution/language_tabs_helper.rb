module Solution::LanguageTabsHelper

  LANGUAGE_TAB_LIMIT = 5
	def article_language_tabs

    # Create Primary's tab
    # Create Agent's tab if eligible and exists
    # Show more tabs of existing trans (LIMIT - current_size - 1) - We still have 1 spot remaining.
    # If current lang is already in list ignore and add one more from existing trans.
    # If current lang is not there, add it now.
    # If there is still a spot pending and agent's tab is eligible but not existing, show it here.

    # If there is just one lang left in total, just display it instead of dropdown.
    initialize_variables
    [create_primary_tab, create_agent_tab, more_tabs].join.html_safe
  end

  def initialize_variables
    @lang_objs = Account.current.supported_languages_objects
    @versions_array = @article_meta.versions
    @tab_count = 0
  end

  def create_primary_tab
    tab_for_article(@article_meta.versions.select { |a| a.language == Account.current.language_object }.first)
  end

  def create_agent_tab
    tab_for_article(agent_lang_article) if lang_flag(User.current.language_object)
  end

  def more_tabs
    output = ""
    output << more_translation_tabs
    output << current_language_tab
    output << remaining_tabs unless tab_limit_reached
    output
  end

  def more_translation_tabs
    output = ""
    @versions_array.each do |a|
      break if @tab_count == (LANGUAGE_TAB_LIMIT - 1)
      output << tab_for_article(a)
    end
    output
  end

  def current_language_tab
    lang = Language.find_by_code(params[:language])
    if current_lang_version?
      tab_for_article(@article)
    elsif lang.present?
      create_new_tab(lang)
    else
      ""
    end
  end

  def current_lang_version?
    @article.present? && @lang_objs.include?(@article.language)
  end

  def remaining_tabs
    output = ""
    output << tab_for_article(@versions_array.first)
    output << create_new_tab(User.current.language_object) unless tab_limit_reached
    output
  end

  def create_new_tab lang
    return "" unless lang_flag(lang)
    new_language_tab(lang)
  end

  def tab_for_article article
    return "" unless article.present?
    update_variables(article.language)
    @versions_array -= [article]
    #BinaryRewrite!
    language_tab(article)
  end

  def language_tab article
    generate_tab(article.language, solution_article_version_path(@article_meta.id, article.language.code), (article.outdated? ? 'outdated' : 'active'))
  end

  def new_article_tab
    generate_tab(Account.current.language_object, new_solution_article_path(:folder_id => params[:folder_id]))
  end

  def new_language_tab language
    update_variables(language)
    generate_tab(language, solution_new_article_version_path(@article_meta.id, language.code))
  end

  def update_variables language
    @lang_objs -= [language]
    @tab_count += 1
  end

  def generate_tab language, path, state=""
    op = ""
    op << "<div class='lang-tab #{'selected' if language == @language}'>"
    op << pjax_link_to(language_tab_common(language, state), path)
    op << "</div>"
    op.html_safe
  end

  def language_tab_common language, status = ""
    "<span class='language_symbol #{status}'>
      <span class='language_name'>
        #{language.short_code.capitalize}
      </span>
    </span>
    <span class='language_label'>
      #{language.name}
    </span>".html_safe
  end

  def agent_lang_article
    article_for_language(User.current.language_object)
  end

  def lang_flag lang
    @lang_objs.include?(lang)
  end

  def tab_limit_reached
    @tab_count == LANGUAGE_TAB_LIMIT
  end

  def extra_tab
    @versions_array.present? ? tab_for_article(@versions_array.first) : new_language_tab(@lang_objs.first)
  end

  def article_versions_dropdown
    select_tag :code,
      options_for_select(@lang_objs.collect { |lang| generate_option(lang) }
      ), {
          :class => 'input-small m0 tooltip',
          :id => 'version_selection',
          :include_blank => true,
          :"data-html" => true,
          :"data-article-id" => @article_meta.id,
          :placeholder => t('solution.articles.more_languages', :count => @lang_objs.size)
        }
  end

  def generate_option lang
    art = article_for_language(lang)
    [lang.name, lang.code, :"data-code" => lang.short_code.capitalize, :"data-state" => (art.present? ? (art.outdated ? "outdated" : "active") : "")]
  end

  def article_for_language lang
    @article_meta.versions.select { |a| a.language_id == lang.id }.first
  end
end