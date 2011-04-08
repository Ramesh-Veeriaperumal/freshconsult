class SearchController < ApplicationController
  before_filter( :only => [ :suggest, :index ] ) { |c| c.requires_permission :manage_tickets }
  
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
    search_content [Solution::Article, Topic]
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
    def search_content(f_classes)
      s_options = { :account_id => current_account.id }
      s_options.merge!(:is_public => true) unless (current_user && !current_user.customer?)
      s_options.merge!(:category_id => params[:category_id]) unless params[:category_id].blank?
      
      @items = ThinkingSphinx.search params[:search_key], 
                                    :with => s_options,#, :star => true
                                    :classes => f_classes, :per_page => 10
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
  
    def search
      @items = ThinkingSphinx.search params[:search_key], 
                                        :with => { :account_id => current_account.id, :deleted => false }, 
                                        :star => true, :page => params[:page], :per_page => 10
  
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
end
