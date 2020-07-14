class Search::V2::Mobile::SuggestController < Search::V2::SpotlightController
  
  before_filter :set_native_mobile, only: [:index]

  def index
    search(esv2_agent_models)
  end

  private
  
    # Mobile passes model to scan as param rather than path like web
    # Also, archive tickets are not accessible on mobile
    def esv2_mobile_klasses
      mobile_klasses = []

      case params[:search_class].to_s
      when "ticket"
        @search_context = :mobile_suggest_tickets
        mobile_klasses.push('Helpdesk::Ticket')
      when "customer"
        @search_context = :mobile_suggest_customers
        mobile_klasses.concat(['User', 'Company']) if privilege?(:view_contacts)
      when "solutions"
        @search_context = :mobile_suggest_solutions
        mobile_klasses.push('Solution::Article') if privilege?(:view_solutions)
      when "forums"
        @search_context = :mobile_suggest_topics
        mobile_klasses.push('Topic') if privilege?(:view_forums)
      else
        @search_context = :mobile_suggest_global
        esv2_klasses
      end
    end
  
    def process_results
      @result_set.each do |result|
        @result_json[:results] << result.to_mob_json_search if result
      end
      
      # This block might not be used by mobile. But just in case.
      #
      @result_json[:current_page] = @current_page
      @total_pages                = (@result_set.total_entries.to_f / @size).ceil

      handle_rendering
    end

    def handle_rendering
      respond_to do |format|
        format.any(:nmobile,:json) do
          render :json => @result_json[:results]
        end
      end
    end

    def initialize_search_parameters
      super
      @klasses        = esv2_mobile_klasses
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_mobile_suggest ||= {
        'company'       => { model: 'Company',                  associations: [] }, 
        'topic'         => { model: 'Topic',                    associations: [ :forum ] }, 
        'ticket'        => { model: 'Helpdesk::Ticket',         associations: [{ flexifield: :flexifield_def }, :ticket_states, :requester, :ticket_old_body, :ticket_status ] }, 
        'article'       => { model: 'Solution::Article',        associations: [] }, 
        'user'          => { model: 'User',                     associations: [ :avatar, :default_user_company, :companies ] }
      }
    end
end
