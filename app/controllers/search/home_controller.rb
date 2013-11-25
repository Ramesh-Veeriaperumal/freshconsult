# encoding: utf-8
class Search::HomeController < ApplicationController

  before_filter :load_ticket, :only => [:related_solutions, :search_solutions]

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

  def related_solutions
    render :layout => false
  end

  def search_solutions
    render :layout => false
  end

  # Search query
  def search(search_in = nil)
    # The :load => true option will load the final results from database. It uses find_by_id internally.
    begin
      @total_results = 0
      if privilege?(:manage_tickets)
        Search::EsIndexDefinition.es_cluster(current_account.id)
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
          search.highlight :desc_un_html, :title, :description, :subject, :job_title, :name, :options => { :tag => '<strong>', :fragment_size => 200, :number_of_fragments => 4, :encoder => 'html' }
        end
      end
      @search_results = @items.results
      process_results unless is_native_mobile?
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def process_results
    results = Hash.new
    @search_results.each_with_hit do |result,hit|
      results[result.class.name] ||= []
      result = SearchUtil.highlight_results(result, hit) unless hit['highlight'].blank?
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

    def load_ticket
      @ticket = current_account.tickets.find_by_id(params[:ticket])
    end
  
    def searchable_classes
      to_ret = "" 
      respond_to do |format|
        format.html do
           to_ret = all_classes
        end
        format.nmobile do 
          if(params[:search_class].to_s.eql?("ticket"))
            to_ret = [ Helpdesk::Ticket ]
          elsif (params[:search_class].to_s.eql?("solutions"))
            to_ret = [ Solution::Article ] if privilege?(:view_solutions)
          elsif (params[:search_class].to_s.eql?("forums"))
            to_ret = [ Topic ] if privilege?(:view_forums)
          elsif (params[:search_class].to_s.eql?("customer"))
            if privilege?(:view_contacts)
              to_ret = [Customer] 
              to_ret << User
            end
          else
            to_ret = all_classes
           end
        end
      end
      to_ret
      # to_ret.map { |to_ret| to_ret = to_ret.document_type }
    end

    def all_classes
          classes = [ Helpdesk::Ticket ]
          classes << Helpdesk::Note unless current_user.restricted? or is_native_mobile?
          classes << Solution::Article if privilege?(:view_solutions) 
          classes << Topic             if privilege?(:view_forums)
          if privilege?(:view_contacts)
             classes << User
             classes << Customer
          end
        classes
    end

end
