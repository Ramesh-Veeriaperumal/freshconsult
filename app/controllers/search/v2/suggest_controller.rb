class Search::V2::SuggestController < Search::V2::SpotlightController

  attr_accessor :result_json, :search_key, :total_pages, :current_page, :search_results, :suggest

  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_spotlight_models = {
    'company'       => { model: 'Company',                  associations: [] }, 
    'topic'         => { model: 'Topic',                    associations: [ :forum ] }, 
    'ticket'        => { model: 'Helpdesk::Ticket',         associations: [{ flexifield: :flexifield_def }, :ticket_states ] }, 
    'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] }, 
    'article'       => { model: 'Solution::Article',        associations: [] }, 
    'user'          => { model: 'User',                     associations: [] }
  }

  def index
    search
  end

  private

    def handle_rendering
      respond_to do |format|
        format.json do
          @result_json.merge!({
            :term => @search_key,
            :more_results_text => 
                (@total_pages > @current_page ? t('search.see_more_results', :term => h(@search_key)).html_safe : nil),
            :no_results_text => (t('search.no_results_msg') if @search_results.size.zero?)
          })
          render :json => @result_json
        end
      end
    end

    def initialize_search_parameters
      super
      @suggest = true
    end
end