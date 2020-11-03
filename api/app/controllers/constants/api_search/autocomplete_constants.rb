module ApiSearch::AutocompleteConstants
  LOAD_OBJECT_EXCEPT = [:requesters, :agents, :companies, :companies_search, :tags].freeze
  AUTOCOMPLETE_PERMITTED_PARAMS = %i[name term query all context search_key q v only limit max_matches per_page page].freeze
  COMPANIES_FIELDS = %w[name].freeze
  VALIDATION_CLASS = 'ApiSearch::AutocompleteValidation'.freeze
  AGENTS_FIELDS = AUTOCOMPLETE_PERMITTED_PARAMS.reject { |term| term == :name }
  AUTOCOMPLETE_MODELS = {
    'user'    => { model: 'User',           associations: [:user_emails] },
    'company' => { model: 'Company',        associations: [] },
    'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
  }.freeze
end
