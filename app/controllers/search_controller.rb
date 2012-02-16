
class SearchController < ApplicationController
  
  extend NewRelic::Agent::MethodTracer
  
  before_filter( :only => [ :suggest, :index ] ) { |c| c.requires_permission :manage_tickets }
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
      
      if main_portal?
        @items = ThinkingSphinx.search params[:search_key], 
                                      :with => s_options,#, :star => true
                                      :classes => f_classes, :per_page => 10
      else
        search_portal_content(f_classes, s_options)
      end
      
      process_results
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
                                  :per_page => 10)
      end
      
      if f_classes.include?(Topic) && current_portal.forum_category_id
        s_options[:category_id] = current_portal.forum_category_id
        @items.concat(Topic.search params[:search_key], :with => s_options, :per_page => 10)
      end
    end
  
    def search
      @items = ThinkingSphinx.search params[:search_key], 
                                        :with => { :account_id => current_account.id, :deleted => false }, 
                                        :star => Regexp.new('\w+@*\w+', nil, 'u'), :match_mode => :any, 
                                        :page => params[:page], :per_page => 10
        process_results
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
      
      @total_results = @items.size
      @search_key = params[:search_key]
    end
  
    def forums_allowed_in_portal?
      render :nothing => true and return unless (feature?(:forums) && allowed_in_portal?(:open_forums))
    end
  
    def solutions_allowed_in_portal? #Kinda duplicate
      render :nothing => true and return unless allowed_in_portal?(:open_solutions)
    end
end
