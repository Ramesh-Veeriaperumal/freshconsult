class Search::V2::Mobile::AutocompleteController < Search::V2::AutocompleteController
  
  before_filter :set_native_mobile, only: [:requesters, :agents, :companies, :tags, :autocomplete_requesters]
  
  def autocomplete_requesters
    @klasses        = ['User']
    @search_context = :requester_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          id: result.email,
          value: result.name,
          user_id: result.id
        }])
      end
    end
  end

  private

    def handle_rendering
      respond_to do |format|
        format.nmobile { render :json => self.search_results.to_json }
        format.all  { render json: [], status: 403 }
      end
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_autocomplete_models
      @@esv2_mobile_autocomplete ||= {
        'user'    => { model: 'User',           associations: [{ :account => :features }, :user_emails] },
        'company' => { model: 'Company',        associations: [] },
        'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
      }
    end
end