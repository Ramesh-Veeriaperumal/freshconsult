module InstalledApplicationConstants
  INDEX_FIELDS = %w(name).freeze
  FETCH_FIELDS = %w(event payload).freeze
  VALIDATION_CLASS = 'InstalledApplicationValidation'.freeze
  INSTALLED_APPLICATION_CONSTANTS = 'InstalledApplicationConstants'.freeze
  APP_NAME_TO_SERVICE_MAP = {
    salesforce: "salesforce",
    salesforce_v2: "salesforce",
    freshsales: "freshsales"
  }.freeze
  EVENTS_REQUIRES_TYPE_VALUE = ['fetch_user_selected_fields'].freeze
  EVENTS_REQUIRES_PAYLOAD = ['fetch_user_selected_fields', 'integrated_resource',
                             'create_contact', 'fetch_dropdown_choices', 'fetch_autocomplete_results', 'create_lead'].freeze
  EVENTS = ['fetch_user_selected_fields', 'integrated_resource', 'fetch_form_fields',
            'create_contact', 'fetch_dropdown_choices', 'fetch_autocomplete_results', 'create_lead'].freeze
  INTEGRATED_RESOURCE = 'integrated_resource'.freeze
  ENTITY_TYPES = ['contact', 'lead', 'account', 'opportunity', 'deal'].freeze
  FRESHSALES_ONLY_EVENTS = ['fetch_form_fields', 'create_contact', 'fetch_dropdown_choices',
                            'fetch_autocomplete_results', 'create_lead'].freeze
end.freeze
