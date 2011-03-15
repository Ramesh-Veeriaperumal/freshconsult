class SearchController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }
  
  #by Shan
  #To do.. some smart meta-programming
  def index 
    search 
  end
  
  def suggest
    search
    render :partial => '/search/navsearch_items'    
  end
  
  protected
    def search
      @items = ThinkingSphinx.search params[:search_key], 
                                        :with => { :account_id => current_account.id, :deleted => false }, 
                                        :star => true, :page => params[:page], :per_page => 10
  
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
