class Helpdesk::Note < ActiveRecord::Base
  def self.const_missing(constant_name, *args)
    if [:SOURCES, :SOURCE_KEYS_BY_TOKEN, :ACTIVITIES_HASH, :TICKET_NOTE_SOURCE_MAPPING, :SOURCE_NAMES_BY_KEY, :BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES, :EXCLUDE_SOURCE].include?(constant_name)
      new_constant_name = 'Helpdesk::Note::'+ constant_name.to_s + '_1'
      Rails.logger.debug("Warning accessing note constants :: #{new_constant_name}")
      Rails.logger.debug(caller[0..10].join("\n"))
      new_constant_name.constantize
    else
      Rails.logger.debug("Constant missing #{constant_name}")
      Rails.logger.debug(caller[0..10].join("\n"))
      super(constant_name, *args)
    end
  end

  SOURCES_1 = %w{email form note status meta twitter feedback facebook forward_email  
               phone mobihelp mobihelp_app_review ecommerce summary canned_form automation_rule automation_rule_forward}  

  NOTE_TYPE = { true => :private, false => :public }

  SOURCE_KEYS_BY_TOKEN_1 = Hash[*SOURCES_1.zip((0..SOURCES_1.size-1).to_a).flatten] 

  ACTIVITIES_HASH_1 = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:twitter] => "twitter",  Helpdesk::Note::SOURCE_KEYS_BY_TOKEN_1["ecommerce"] => "ecommerce" }  

  TICKET_NOTE_SOURCE_MAPPING_1 = {  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:email] => SOURCE_KEYS_BY_TOKEN_1["email"] ,   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:portal] => SOURCE_KEYS_BY_TOKEN_1["email"] ,  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:phone] => SOURCE_KEYS_BY_TOKEN_1["email"] ,   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:forum] => SOURCE_KEYS_BY_TOKEN_1["email"] ,   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:twitter] => SOURCE_KEYS_BY_TOKEN_1["twitter"] ,   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:facebook] => SOURCE_KEYS_BY_TOKEN_1["facebook"] ,   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:chat] => SOURCE_KEYS_BY_TOKEN_1["email"], 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:bot] => SOURCE_KEYS_BY_TOKEN_1['email'],  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:mobihelp] => SOURCE_KEYS_BY_TOKEN_1["mobihelp"],  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:feedback_widget] => SOURCE_KEYS_BY_TOKEN_1["email"],  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:outbound_email] => SOURCE_KEYS_BY_TOKEN_1["email"], 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:ecommerce] => SOURCE_KEYS_BY_TOKEN_1['ecommerce'],  
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:canned_form] => SOURCE_KEYS_BY_TOKEN_1['canned_form'] 
  } 

  SOURCE_NAMES_BY_KEY_1 = SOURCE_KEYS_BY_TOKEN_1.invert

  # IMP: Whenever a new category is added, it must be handled in reports accordingly.
  CATEGORIES = {
    :customer_response => 1,
    :agent_private_response => 2,
    :agent_public_response => 3,
    :third_party_response => 4,
    :meta_response => 5,
    :reply_to_forward => 6,  # Used for conversation with third party
    :customer_feedback => 7,
    :broadcast => 8
  }

  CATEGORIES_NAMES_BY_KEY = CATEGORIES.invert

  NER_DATA_TIMEOUT = 30.days.to_i

  EXCLUDE_SOURCE_1 =  %w{meta summary}.freeze

  RELATED_ASSOCIATIONS = %w{note_body schema_less_note}.freeze

  PERMITTED_PARAMS = [
    { attachments: [:resource] },
    { inline_attachment_ids: [] },
    { note_body_attributes: [:body_html] }
  ]

  BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES_1 = [SOURCE_KEYS_BY_TOKEN_1['feedback'], SOURCE_KEYS_BY_TOKEN_1['meta'], SOURCE_KEYS_BY_TOKEN_1['summary'], 
                                                 SOURCE_KEYS_BY_TOKEN_1['automation_rule_forward'], SOURCE_KEYS_BY_TOKEN_1['automation_rule']].freeze
end
