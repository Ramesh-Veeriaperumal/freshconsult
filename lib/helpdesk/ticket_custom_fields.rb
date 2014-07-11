module Helpdesk::TicketCustomFields
  def self.included(base)
    base.send :include, InstanceMethods
  end

  module InstanceMethods

  	def custom_fields
      @custom_fields = FlexifieldDef.all(:include => 
        [:flexifield_def_entries =>:flexifield_picklist_vals], 
        :conditions => ['account_id=? AND module=?',account_id,'Ticket'] ) 
    end

    def custom_field_attribute attribute, args    
      RAILS_DEFAULT_LOGGER.debug "method_missing :: custom_field_attribute  args is #{args.inspect}  and attribute: #{attribute}"

      attribute = attribute.to_s
      return custom_field[attribute] unless attribute.include?("=")
        
      field = attribute.to_s.chomp("=")
      args = args.first if !args.blank? && args.is_a?(Array) 
      self.ff_def = FlexifieldDef.find_by_account_id_and_module(self.account_id, 'Ticket').id
      set_ff_value field, args
    end

    private

      def custom_field_aliases
        return flexifield ? ff_aliases : account.flexi_field_defs.first.ff_aliases
      end

  end

end