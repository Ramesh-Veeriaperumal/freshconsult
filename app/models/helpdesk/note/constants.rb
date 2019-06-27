class Helpdesk::Note < ActiveRecord::Base

  SOURCES = %w{email form note status meta twitter feedback facebook forward_email
               phone mobihelp mobihelp_app_review ecommerce summary canned_form automation_rule
               automation_rule_forward}

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
	  Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:ecommerce] => SOURCE_KEYS_BY_TOKEN['ecommerce'],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:canned_form] => SOURCE_KEYS_BY_TOKEN['canned_form']
  }

  SOURCE_NAMES_BY_KEY = SOURCE_KEYS_BY_TOKEN.invert
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

  EXCLUDE_SOURCE =  %w{meta summary}.freeze

  RELATED_ASSOCIATIONS = %w{note_body schema_less_note}.freeze

  PERMITTED_PARAMS = [
    { attachments: [:resource] },
    { inline_attachment_ids: [] },
    { note_body_attributes: [:body_html] }
  ]

  BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES = [SOURCE_KEYS_BY_TOKEN['feedback'], SOURCE_KEYS_BY_TOKEN['meta'], SOURCE_KEYS_BY_TOKEN['summary'],
                                                 SOURCE_KEYS_BY_TOKEN['automation_rule_forward'], SOURCE_KEYS_BY_TOKEN['automation_rule']].freeze

end