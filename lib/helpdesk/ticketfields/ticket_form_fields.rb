# only for migration purpose....

module Helpdesk::Ticketfields::TicketFormFields

	def save_form_field(ticket_field)
    form_id = ticket_field.account.default_form.id
    tkt_f_f = TicketFormField.find_or_initialize_by_account_id_and_form_id_and_ticket_field_id(
    	ticket_field.account_id,form_id,ticket_field.id) do |tkt_form_field|
    		tkt_form_field.field_alias = ticket_field.name
    		tkt_form_field.position = ticket_field.position
	    	tkt_form_field.ff_col_name = ticket_field.flexifield_def_entry.flexifield_name unless ticket_field.is_default_field?
	  end

    # need to populate ticket type values.
    save_ticket_type_values(ticket_field) if(ticket_field.field_type == 'default_ticket_type')

	  begin
	  	if tkt_f_f.new_record?
        tkt_f_f.save!
      else
        tkt_f_f.insert_at(ticket_field.position) unless ticket_field.position.blank?
      end
  	rescue Exception => error
			NewRelic::Agent.notice_error(error)
		end
  end

  # deleting all the picklist values and recreating.
  def save_ticket_type_values(ticket_field)
    tkt_field_values = TicketFieldValue.find(:all,
      :conditions=>{ :ticket_field_id => ticket_field.id, :account_id => ticket_field.account_id})
    tkt_field_values.each{|tkt_field_value| tkt_field_value.destroy}

    form_id = ticket_field.account.default_form.id
    # begin
    ticket_field.choices.each_with_index do |choice,position|
      TicketFieldValue.new(
        :account_id => ticket_field.account_id,
        :form_id => form_id,
        :ticket_field_id => ticket_field.id,
        :value => choice[0],
        :position => position
      ).save!   
    end
  end

  def remove_form_field(ticket_field)
    tkt_f_f = TicketFormField.find(:first, :conditions => { :account_id =>  ticket_field.account_id,
                      :form_id => ticket_field.account.default_form.id,
                      :ticket_field_id => ticket_field.id})
    begin
    	tkt_f_f.destroy
    rescue Exception => error
			NewRelic::Agent.notice_error(error)
		end
  end

  # only for level 2 & 3.
  def save_form_nested_field(nested_field)

  	tkt_f = Helpdesk::TicketField.find_or_initialize_by_account_id_and_name(
  		nested_field.account_id,nested_field.name) do |ticket_field|
  			ticket_field.label = nested_field.label
  			ticket_field.label_in_portal = nested_field.label_in_portal
  			ticket_field.field_type = 'nested_field'
  			ticket_field.flexifield_def_entry_id = nested_field.flexifield_def_entry_id
  			ticket_field.level = nested_field.level
  			ticket_field.parent_id = nested_field.ticket_field_id
  	end
  	
  	begin
      if tkt_f.new_record?
	  	  tkt_f.save!
      else
        tkt_f.update_attributes(:label => nested_field.label, 
          :label_in_portal => nested_field.label_in_portal)
      end
  	rescue Exception => error
			NewRelic::Agent.notice_error(error)
		end
  end

  # only for level 2 & 3.
  def remove_form_nested_field(nested_field)
    tkt_f = Helpdesk::TicketField.find(:first, 
              :conditions => {:account_id => nested_field.account_id,
              :name => nested_field.name})
    begin
    	tkt_f.destroy unless tkt_f.nil?
    rescue Exception => error
			NewRelic::Agent.notice_error(error)
		end
  end

end