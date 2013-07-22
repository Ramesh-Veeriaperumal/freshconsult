# encoding: utf-8
class Search::HomeController < ApplicationController

  def index
    search(searchable_classes)
  end

  def suggest
    search(searchable_classes)
    render :partial => '/search/home/navsearch_items'
  end

  def solutions
    search [Solution::Article]
    post_process 'solutions'
  end

  def topics
    search [Topic]
    post_process 'topics'
  end

  # Search query
  def search(search_in = nil)
    if current_account.es_enabled?
      # The :load => true option will load the final results from database. It uses find_by_id internally.
      begin
        @total_results = 0
        if privilege?(:manage_tickets)
          options = { :load => true, :page => (params[:page] || 1), :size => 10, :preference => :_primary_first }
          @items = Tire.search Search::EsIndexDefinition.searchable_aliases(search_in, current_account.id), options do |search|
            search.query do |query|
              query.filtered do |f|
                if SearchUtil.es_exact_match?(params[:search_key])
                  f.query { |q| q.text :_all, SearchUtil.es_filter_exact(params[:search_key]), :type => :phrase }
                else
                  f.query { |q| q.string SearchUtil.es_filter_key(params[:search_key]), :analyzer => "include_stop" }
                end
                f.filter :or, { :not => { :exists => { :field => :deleted } } },
                              { :term => { :deleted => false } }
                f.filter :or, { :not => { :exists => { :field => :spam } } },
                              { :term => { :spam => false } }
                f.filter :term, { :account_id => current_account.id }
                if current_user.restricted?
                  user_groups = current_user.group_ticket_permission ? current_user.agent_groups.map(&:group_id) : []
                  f.filter :or, { :not => { :exists => { :field => :responder_id } } },
                                { :term => { :responder_id => current_user.id } },
                                { :terms => { :group_id => user_groups } }
                else
                  f.filter :or, { :not => { :exists => { :field => :notable_deleted } } },
                                { :term => { :notable_deleted => false } }
                  f.filter :or, { :not => { :exists => { :field => :notable_spam } } },
                                { :term => { :notable_spam => false } }
                end
                unless search_in.blank?
                  f.filter :term,  { 'folder.category_id' => params[:category_id] } if params[:category_id] && search_in.include?(Solution::Article)
                  f.filter :term,  { 'forum.forum_category_id' => params[:category_id] } if params[:category_id] && search_in.include?(Topic)
                end
              end
            end
            search.from options[:size].to_i * (options[:page].to_i-1)
            search.highlight :desc_un_html, :title, :description, :subject, :job_title, :name, :options => { :tag => '<strong>', :fragment_size => 200, :number_of_fragments => 4 }
          end
        end
        process_results
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    else
      redirect_to search_index_url(:search_key => params[:search_key])
    end
  end

  def process_results
    
    results = Hash.new
    @search_results = @items.results

    @search_results.each_with_hit do |result,hit|
      results[result.class.name] ||= []
      result = highlight_results(result, hit) unless hit['highlight'].blank?
      results[result.class.name] << result
    end
    
    @searched_tickets   = results['Helpdesk::Ticket']
    @searched_articles  = results['Solution::Article']
    @searched_users     = results['User']
    @searched_companies = results['Customer']
    @searched_topics    = results['Topic']
    @searched_notes     = results['Helpdesk::Note']
    
    @search_key = params[:search_key].gsub(/\\/,'')
    @total_results = @items.results.size

    rescue Exception => e
      NewRelic::Agent.notice_error(e)
  end

  def highlight_results(result, hit)
    unless result.blank?
      hit['highlight'].keys.each do |i|
        result[i] = hit['highlight'][i].to_s
      end
    end
    result
  end

  def post_process item
    respond_to do |format|
      format.html { render :partial => '/search/home/search_results'  }
      format.xml  { 
        api_xml = []
        api_xml = @searched_articles.to_xml  if item == 'solutions' and !@searched_articles.nil?
        api_xml = @searched_topics.to_xml  if item == 'topics' and !@searched_topics.nil?
        render :xml => api_xml
      }
    end
  end
  
  private
  
    def searchable_classes
      to_ret = [ Helpdesk::Ticket ]
      to_ret << Helpdesk::Note unless current_user.restricted?
      to_ret << Solution::Article if privilege?(:view_solutions)
      to_ret << Topic             if privilege?(:view_forums)
      
      if privilege?(:view_contacts)
        to_ret << User
        to_ret << Customer
      end
      to_ret
      # to_ret.map { |to_ret| to_ret = to_ret.document_type }
    end

end
