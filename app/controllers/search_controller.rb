class SearchController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }
  
  #by Shan
  #To do.. some smart meta-programming
  def index
    items = ThinkingSphinx.search params[:search_key], 
                                      :with => { :account_id => current_account.id, :deleted => false }, 
                                      :star => true, :per_page => 10

    results = Hash.new
    items.each do |i|
      results[i.class.name] ||= []
      results[i.class.name] << i
    end
    
    @tickets = results['Helpdesk::Ticket']
    @articles = results['Solution::Article']
    @users = results['User']
    @companies = results['Customer']
    @topics = results['Topic']
    
    @total_results = items.size
    @search_key = params[:search_key]
    render :partial => '/layouts/shared/navsearch_items'
  end
end
