module Search::SearchHelper
	include Helpdesk::TicketsHelperMethods

	def search_sort_menu
		@search_sort = @search_sort || 'relevance'
		sort_menu = ["relevance", "created_at", "updated_at"].each_with_index.map do |s, i|
						[ 	t("search.sort_by.#{s}"), send("search_#{current_filter}_path", {:term => @search_key, :search_sort => s}),
							(@search_sort.to_s == s) ]
					end
		
		%(	<a role="button" class="dropdown-toggle" id="sorting_dropdown" data-toggle="dropdown" href="#"> 
				<b>#{t("search.sort_by.#{@search_sort}")}</b><b class="caret"></b>
			</a>
			#{dropdown_menu sort_menu, 
			{:remote => true, 'data-loading' => "result-wrapper", 'data-loading-classes' => "sloading loading-small", 'data-type' => "script", "data-hide-before" => "#search-page-results"}}).html_safe
	end

	def search_filter_tabs
		options = current_user && current_user.agent? ? {:"data-pjax" => "#body-container"} : {}

		search_tabs = [ [t('search.all_results'), 'all', 
						"/search/all?term=#{CGI.escape(@search_key)}", privilege?(:manage_tickets)],
					[t('search.tickets'), 'tickets', 
						search_tickets_path(:term => @search_key), privilege?(:manage_tickets)],
					[t('search.solutions'), 'solutions', 
						search_solutions_path(:term => @search_key), privilege?(:view_solutions)],
					[t('search.forums'), 'forums', 
					    search_forums_path(:term => @search_key), privilege?(:view_forums)],
					[t('search.customers'), 'customers', 
						search_customers_path(:term => @search_key), privilege?(:view_contacts)]]

		(content_tag(:li, :class => 'muted') do
			content_tag(:label, t('search.showing'), {:class => 'title-text'}).to_s.html_safe
		end) +
		(search_tabs.map{ |search_tab| 
			if search_tab[3]
				content_tag(:li, :class => (current_filter == search_tab[1]) ? 'active' : '') do
					link_to( search_tab[0].html_safe, search_tab[2], options ) 
				end.to_s.html_safe
			end
		}).to_s.html_safe
	end

	def current_filter
		request.path.split('/').last
	end
  
  def insert_link_params(article, url)
    [
      article.parent_id, 
      url,
      escape_javascript(article.title)
    ].collect {|s| "'#{s}'"}.join(', ')
  end
  
  def insert_content_params(article, url)
    [
      article.parent_id, 
      url,
      (current_account.multilingual? && article.language.code) || nil
    ].compact.collect {|s| "'#{s}'"}.join(', ')
  end
end