class SearchController < ApplicationController
  skip_before_filter :check_privilege
  extend NewRelic::Agent::MethodTracer
  
  include SearchUtil

  before_filter :forums_allowed_in_portal?, :only => :topics
  before_filter :solutions_allowed_in_portal?, :only => :solutions
  
  #by Shan
  #To do.. some smart meta-programming
  def index 
    search 
  end
  
  def suggest
    search
    render :partial => '/search/navsearch_items'    
  end
  
  def content
    to_search = content_classes
    render :nothing => true and return if to_search.empty?
      
    search_content to_search
  end
  
  def solutions
    @skip_title = true
    search_content [Solution::Article]
 end
  
  def topics
    @skip_title = true
    search_content [Topic]
  end

  def widget_solutions
    @widget_solutions = true
    solutions
  end
  
  protected
    
    def content_classes
      to_ret = Array.new
      to_ret << Solution::Article if allowed_in_portal?(:open_solutions)
      to_ret << Topic if (feature?(:forums) && allowed_in_portal?(:open_forums))
      
      to_ret
    end
    
 
    def content_visibility(f_classes)        
      if (f_classes.include?(Solution::Article))        
        solution_visibility
      else        
        forum_visibility
      end      
    end
    
    
    def search_content(f_classes)
      s_options = { :account_id => current_account.id }      
      s_options.merge!(:category_id => params[:category_id]) unless params[:category_id].blank?
      s_options.merge!({:visible => 1, :company => 1})

      s_options.merge!(:status => 2) if f_classes.include?(Solution::Article) and (current_user.blank? || current_user.customer?)
      begin
        if main_portal?
          @items = ThinkingSphinx.search params[:search_key], 
                                        :with => s_options,
                                        :sphinx_select => content_select(f_classes),
                                        :match_mode => :any,
                                        :max_matches => (4 if @widget_solutions),
                                        :classes => f_classes, :per_page => 10
        else
          search_portal_content(f_classes, s_options)
        end
        process_results
      rescue Exception => e
        @total_results = 0
        NewRelic::Agent.notice_error(e)      
      end
      
      respond_to do |format|
        format.html { render :partial => '/search/search_results'  }
        format.xml  { 
        api_xml = []
        api_xml = @searched_articles.to_xml  if ['Solution::Article'].include? f_classes.first.name and !@searched_articles.nil?
        api_xml = @searched_topics.to_xml  if ['Topic'].include? f_classes.first.name and !@searched_topics.nil?
        
        render :xml => api_xml
        
        }
      end 
           
    end
    
    def search_portal_content(f_classes, s_options)
      @items = []
      if f_classes.include?(Solution::Article) && current_portal.solution_category_id
        s_options[:category_id] = current_portal.solution_category_id
        @items.concat(ThinkingSphinx.search params[:search_key],
                                               :with => s_options,
                                               :classes => [ Solution::Article ],
                                               :sphinx_select => content_select(f_classes),
                                               :max_matches => (4 if @widget_solutions),
                                               :per_page => page_limit)
      end
      
      if f_classes.include?(Topic) && current_portal.forum_category_id
        s_options[:category_id] = current_portal.forum_category_id
        @items.concat(ThinkingSphinx.search params[:search_key],
                        :sphinx_select => content_select(f_classes),
                        :classes => [ Topic ],
                        :with => s_options, :per_page => 10)
      end

    end
  
    def search
      begin
        
        if privilege?(:manage_tickets)
          unless current_account.es_enabled?
            @items = ThinkingSphinx.search filter_key(params[:search_key]), 
                                                                :with => search_with, 
                                                                :classes => searchable_classes,
                                                                :sphinx_select => sphinx_select,
                                                                :star => false,
                                                                :match_mode => :any,                                          
                                                                :page => params[:page], :per_page => 10
          else
            return redirect_to search_home_index_url(:search_key => params[:search_key])
          end
        elsif current_user && current_user.customer?
          search_portal_for_logged_in_user
        end
        process_results
      rescue Exception => e
        @total_results = 0
        NewRelic::Agent.notice_error(e)
      end
    end

    def process_results
      
      results = Hash.new
      @items.each do |i|
        results[i.class.name] ||= []
        results[i.class.name] << i
      end

      
      @searched_tickets   = results['Helpdesk::Ticket']
      @searched_articles  = results['Solution::Article']
      @searched_users     = results['User']
      @searched_companies = results['Customer']
      @searched_topics    = results['Topic']
      
      @search_key = params[:search_key]
      @total_results = @items.size

    end
    
    def page_limit
      return 10
    end

    def forums_allowed_in_portal?
      render :nothing => true and return unless (feature?(:forums) && allowed_in_portal?(:open_forums))
    end
  
    def solutions_allowed_in_portal? #Kinda duplicate
      render :nothing => true and return unless allowed_in_portal?(:open_solutions)
  end

  private
  
  def searchable_classes    
    searchable = [ Helpdesk::Ticket, Solution::Article, User, Customer, Topic ]
    searchable.delete_if{ |c| RESTRICTED_CLASSES.include?(c) } if current_user.restricted?
    
    searchable
  end 
  
  def condition
    return unless current_user.restricted?

    restriction = "responder_id = #{current_user.id} OR responder_id = #{DEFAULT_SEARCH_VALUE}"
    if current_user.agent.group_ticket_permission
      restriction += " OR group_id = #{DEFAULT_SEARCH_VALUE}"

      restriction = current_user.agent_groups.reduce(restriction) do |val, ag|
         "#{val} OR group_id = #{ag.group_id}"
      end 

    end 
        
    restriction
  end

  def visibility_condition f_classes
    condition = "IN (visibility,#{content_visibility(f_classes).join(", ")})" 
  end

  def company_condition
    if (current_user && current_user.has_company?) 
     "visibility = #{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]} AND IN (customer_ids ,#{current_user.customer_id}) OR
     IN(visibility,#{[Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone],Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]].join(',')})" 
    else
     return 1
    end
  end

  def sphinx_select
    select_str = "*"
    select_str += ", IF( #{condition}, 1, 0 ) AS restricted" if current_user.restricted?

    select_str
  end

  def content_select f_classes
    %(*, #{visibility_condition(f_classes)} AS visible, 
       IF(#{company_condition},1,0) AS company)
  end

  def search_with
    with_params = { :account_id => current_account.id, :deleted => false }
    with_params[:restricted] = 1 if current_user.restricted?  
    
    with_params
  end 

   def search_portal_for_logged_in_user
     with_options = { :account_id => current_account.id, :deleted => false, :visibility => [SearchUtil::DEFAULT_SEARCH_VALUE, Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone], Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]]}
     without_options = { :status=>SearchUtil::DEFAULT_SEARCH_VALUE }
     classes = [Helpdesk::Ticket, Solution::Article, Topic]
     sphinx_select = nil

     if current_user.privilege?(client_manager)
       with_options[:customer_id] = [SearchUtil::DEFAULT_SEARCH_VALUE, current_user.customer_id]
     else
       with_options[:requester_id] = [SearchUtil::DEFAULT_SEARCH_VALUE, current_user.id]
     end
     unless current_user.customer_id.blank?
       with_options[:company] = SearchUtil::DEFAULT_SEARCH_VALUE
       with_options[:visibility] = [SearchUtil::DEFAULT_SEARCH_VALUE, Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone], Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users], Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]]
       sphinx_select = %{*, IF( IN(customer_ids, #{current_user.customer_id}) OR IN(visibility,#{Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]},#{Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]}), #{SearchUtil::DEFAULT_SEARCH_VALUE},0) AS company}
     end
     Rails.logger.debug "SSP :with => #{with_options.inspect}, :without => #{without_options.inspect}, :classes => [#{classes.join(',')}], :sphinx_select => #{sphinx_select}"
     @items = ThinkingSphinx.search filter_key(params[:search_key]), 
                                      :with => with_options, 
                                      :without => without_options,
                                      :classes=>classes,
                                      :sphinx_select=>sphinx_select,
                                      :page => params[:page], :per_page => 10
   end

  def filter_key(query)
    email_regex  = Regexp.new('(\b[-a-zA-Z0-9.\'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)', nil, 'u')
    default_regex = Regexp.new('\w+', nil, 'u')
    enu = query.gsub(/("#{email_regex}(.*?#{email_regex})?"|(?![!-])#{email_regex})/u)
    unless enu.count > 0
      enu = query.gsub(/("#{default_regex}(.*?#{default_regex})?"|(?![!-])#{default_regex})/u)
    end
    enu.each do
      pre, proper, post = $`, $&, $'
      is_operator = pre.match(%r{(\W|^)[@~/]\Z}) || pre.match(%r{(\W|^)@\([^\)]*$})
      is_quote    = proper.starts_with?('"') && proper.ends_with?('"')
      has_star    = pre.ends_with?("*") || post.starts_with?("*")
      if is_operator || is_quote || has_star
          proper
      else
         "*#{proper}*"
      end
    end
  end

end
