class Helpdesk::Note < ActiveRecord::Base

	SOURCES = %w{email form note status meta twitter feedback facebook forward_email phone mobihelp mobihelp_app_review ecommerce}

  NOTE_TYPE = { true => :private, false => :public }
  
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.zip((0..SOURCES.size-1).to_a).flatten]
  
  ACTIVITIES_HASH = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => "twitter",  Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["ecommerce"] => "ecommerce" }

  TICKET_NOTE_SOURCE_MAPPING = { 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal] => SOURCE_KEYS_BY_TOKEN["email"] ,
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => SOURCE_KEYS_BY_TOKEN["twitter"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook] => SOURCE_KEYS_BY_TOKEN["facebook"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] => SOURCE_KEYS_BY_TOKEN["email"],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:mobihelp] => SOURCE_KEYS_BY_TOKEN["mobihelp"],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:feedback_widget] => SOURCE_KEYS_BY_TOKEN["email"],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email] => SOURCE_KEYS_BY_TOKEN["email"],
	Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:ecommerce] => SOURCE_KEYS_BY_TOKEN["ecommerce"]
  }

  # IMP: Whenever a new category is added, it must be handled in reports accordingly.
  CATEGORIES = {
    :customer_response => 1,
    :agent_private_response => 2,
    :agent_public_response => 3,
    :third_party_response => 4,
    :meta_response => 5,
    :reply_to_forward => 6  # Used for conversation with third party
  }
	
end