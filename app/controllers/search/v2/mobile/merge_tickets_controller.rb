class Search::V2::Mobile::MergeTicketsController < Search::V2::TicketsController
  
  before_filter :set_native_mobile, only: [:index]
  
  private

    def process_results
      @result_set.each do |result|
        @result_json[:results] << result.to_mob_json_merge_search if result
      end
      handle_rendering
    end
    
    def handle_rendering
      respond_to do |format|
        format.nmobile { render :json => @result_json[:results] }
        format.all  { render json: [], status: 403 }
      end
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_mobile_ticket_merge ||= {
        'ticket'  => { model: 'Helpdesk::Ticket', associations: [ :requester, :tags, :attachments, {:flexifield => [:flexifield_def]} ] }
      }
    end
end