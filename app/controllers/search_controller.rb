
class SearchController < ApplicationController
  
  extend NewRelic::Agent::MethodTracer
  
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
    
    def get_visibility_array
      vis_arr = Array.new
      if permission?(:manage_forums)
        vis_arr = Forum::VISIBILITY_NAMES_BY_KEY.keys
      elsif permission?(:post_in_forums)
        vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone],Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
      else
        vis_arr = [Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
      end
    end
    
    def get_visibility(f_classes)        
      if (f_classes.include?(Solution::Article))        
        Solution::Folder.get_visibility_array(current_user)
      else        
        get_visibility_array
      end      
    end
    
    
    def search_content(f_classes)
      s_options = { :account_id => current_account.id }      
      s_options.merge!(:category_id => params[:category_id]) unless params[:category_id].blank?
      s_options.merge!(:visibility => get_visibility(f_classes)) 
      s_options.merge!(:status => 2) if f_classes.include?(Solution::Article) and (current_user.blank? || current_user.customer?)
      begin
        if main_portal?
          @items = ThinkingSphinx.search params[:search_key], 
                                        :with => s_options,#, :star => true,
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
        @items.concat(Solution::Article.search params[:search_key], :with => s_options,
                                  :max_matches => (4 if @widget_solutions),
                                  :per_page => page_limit)
      end
      
      if f_classes.include?(Topic) && current_portal.forum_category_id
        s_options[:category_id] = current_portal.forum_category_id
        @items.concat(Topic.search params[:search_key], :with => s_options, :per_page => 10)
      end

      if f_classes.include?(Helpdesk::Ticket)
        @items.concat(Helpdesk::Ticket.search params[:search_key], :with => s_options, :per_page => 10)
      end

    end
  
    def search
      begin
        if permission? :manage_tickets
          @items = ThinkingSphinx.search filter_key(params[:search_key]), 
                                          :with => { :account_id => current_account.id, :deleted => false },
                                          :star => false,
                                          :match_mode => :any,
                                          :page => params[:page], :per_page => 10
        else
          search_portal_content [Helpdesk::Ticket], { :account_id => current_account.id, :deleted => false }
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

      @total_results = 0
      @searched_tickets   = results['Helpdesk::Ticket']
      @searched_tickets = @searched_tickets.select {|ticket| ticket.can_access?(current_user)} unless current_user.agent.all_ticket_permission
      @total_results += @searched_tickets.size unless @searched_tickets.nil?
      @searched_articles  = results['Solution::Article']
      @total_results += @searched_articles.size unless @searched_articles.nil?
      @searched_users     = results['User'] unless current_user.can_view_all_tickets?
      @total_results += @searched_users.size unless @searched_users.nil?
      @searched_companies = results['Customer'] unless current_user.can_view_all_tickets?
      @total_results += @searched_companies.size unless @searched_companies.nil?
      @searched_topics    = results['Topic']
      @total_results += @searched_topics.size unless @searched_topics.nil?
      
      @search_key = params[:search_key]
    end
    
    def page_limit
      return 20 if current_user.can_view_all_tickets?
      return 10
    end

    def forums_allowed_in_portal?
      render :nothing => true and return unless (feature?(:forums) && allowed_in_portal?(:open_forums))
    end
  
    def solutions_allowed_in_portal? #Kinda duplicate
      render :nothing => true and return unless allowed_in_portal?(:open_solutions)
  end
  
  private
  
  def filter_key(query)
    email_regex  = Regexp.new('(\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)', nil, 'u')
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
