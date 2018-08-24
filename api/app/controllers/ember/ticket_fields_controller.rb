class Ember::TicketFieldsController < ::ApiTicketFieldsController
  include TicketFieldConcern
  include MemcacheKeys
  
  send_etags_along('TICKET_FIELD_LIST')

  around_filter :run_on_db, :only => :index
  skip_around_filter :run_on_slave

  PRELOAD_ASSOC = [
    :nested_ticket_fields,
    picklist_values: [
      sub_picklist_values: { sub_picklist_values: [:sub_picklist_values] },
      section: [:section_fields, section_picklist_mappings: :picklist_value]
    ]
  ].freeze

  # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
  CURRENT_VERSION = 'private-v3'.freeze
  
  def index
    @ticket_fields_full_mem_key = TICKET_FIELDS_FULL % { :account_id => current_account.id }
    @ticket_fields_full_cache_data = MemcacheKeys.get_from_cache(@ticket_fields_full_mem_key)
    if @ticket_fields_full_cache_data.nil?
      load_objects
    else
      @items = []
    end
  end
  
  def exclude_products
    current_account.products_from_cache.empty?
  end
  

  private

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination 
      @items = items

      # non_db_ticket_fields are added in order to avoid heavy logic in helpkit-ember
      # During CRUD operation, these fields should be excluded by default
      add_non_db_ticket_fields
    end
end
