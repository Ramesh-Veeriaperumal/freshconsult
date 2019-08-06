module ApiSearch::AutocompleteConstants
  LOAD_OBJECT_EXCEPT = [:requesters, :agents, :companies, :companies_search, :tags].freeze
  COMPANIES_FIELDS = %w[name].freeze
  VALIDATION_CLASS = 'ApiSearch::AutocompleteValidation'.freeze
  AUTOCOMPLETE_MODELS = {
    'user'    => { model: 'User',           associations: [:user_emails] },
    'company' => { model: 'Company',        associations: [] },
    'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
  }.freeze
end
