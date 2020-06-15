class Helpdesk::Source < Helpdesk::Choice
  concerned_with :associations, :constants, :validations, :callbacks

  serialize :meta, HashWithIndifferentAccess

  class << self
    def ticket_sources
      TICKET_SOURCES
    end

    def ticket_source_options
      TICKET_SOURCES.map { |i| [i[1], i[2]] }
    end

    def ticket_source_names_by_key
      Hash[*TICKET_SOURCES.map { |i| [i[2], i[1]] }.flatten]
    end

    def ticket_source_keys_by_token
      Hash[*TICKET_SOURCES.map { |i| [i[0], i[2]] }.flatten]
    end

    def ticket_source_keys_by_name
      Hash[*TICKET_SOURCES.map { |i| [i[1], i[2]] }.flatten]
    end

    def ticket_source_token_by_key
      Hash[*TICKET_SOURCES.map { |i| [i[2], i[0]] }.flatten]
    end

    def ticket_sources_for_language_detection
      [ticket_source_keys_by_token[:portal], ticket_source_keys_by_token[:feedback_widget]]
    end

    def note_sources
      NOTE_SOURCES
    end

    def note_source_keys_by_token
      Hash[*NOTE_SOURCES.zip((0..NOTE_SOURCES.size - 1).to_a).flatten]
    end

    def ticket_note_source_mapping
      {
        ticket_source_keys_by_token[:email] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:portal] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:phone] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:forum] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:twitter] => note_source_keys_by_token['twitter'],
        ticket_source_keys_by_token[:facebook] => note_source_keys_by_token['facebook'],
        ticket_source_keys_by_token[:chat] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:bot] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:mobihelp] => note_source_keys_by_token['mobihelp'],
        ticket_source_keys_by_token[:feedback_widget] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:outbound_email] => note_source_keys_by_token['email'],
        ticket_source_keys_by_token[:ecommerce] => note_source_keys_by_token['ecommerce'],
        ticket_source_keys_by_token[:canned_form] => note_source_keys_by_token['canned_form']
      }
    end

    def ticket_bot_source
      ticket_source_keys_by_token[:bot]
    end

    def note_source_names_by_key
      note_source_keys_by_token.invert
    end

    def note_activities_hash
      {
        ticket_source_keys_by_token[:twitter] => 'twitter',
        note_source_keys_by_token['ecommerce'] => 'ecommerce'
      }
    end

    def api_sources
      ticket_source_keys_by_token.slice(:email, :portal, :phone, :twitter, :facebook, :chat, :mobihelp, :feedback_widget, :ecommerce).values
    end

    def api_unpermitted_sources_for_update
      ticket_source_keys_by_token.slice(:twitter, :facebook).values
    end

    def note_exclude_sources
      NOTE_EXCLUDE_SOURCES
    end

    def note_blacklisted_thank_you_detector_note_sources
      [
        note_source_keys_by_token['feedback'],
        note_source_keys_by_token['meta'],
        note_source_keys_by_token['summary'],
        note_source_keys_by_token['automation_rule_forward'],
        note_source_keys_by_token['automation_rule']
      ]
    end

    def archive_note_sources  
      ARCHIVE_NOTE_SOURCES  
    end 

    def archive_note_source_keys_by_token 
      Hash[*ARCHIVE_NOTE_SOURCES.zip((0..ARCHIVE_NOTE_SOURCES.size-1).to_a).flatten]  
    end 

    def archive_note_ticket_note_source_mapping 
      { 
        ticket_source_keys_by_token[:email] => note_source_keys_by_token['email'],  
        ticket_source_keys_by_token[:portal] => note_source_keys_by_token['email'], 
        ticket_source_keys_by_token[:phone] => note_source_keys_by_token['email'],  
        ticket_source_keys_by_token[:forum] => note_source_keys_by_token['email'],  
        ticket_source_keys_by_token[:twitter] => note_source_keys_by_token['twitter'],  
        ticket_source_keys_by_token[:facebook] => note_source_keys_by_token['facebook'],  
        ticket_source_keys_by_token[:chat] => note_source_keys_by_token['email'], 
        ticket_source_keys_by_token[:mobihelp] => note_source_keys_by_token['mobihelp'],  
        ticket_source_keys_by_token[:feedback_widget] => note_source_keys_by_token['email'] 
      } 
    end 

    def archive_note_activities_hash  
      { 
        ticket_source_keys_by_token[:twitter] => 'twitter'  
      } 
    end 

    def default_ticket_sources  
      TICKET_SOURCES  
    end 

    def default_ticket_source_names_by_key  
      Hash[*TICKET_SOURCES.map { |i| [i[2], i[1]] }.flatten]  
    end
  end

  def new_response_hash
    {
      label: name,
      value: account_choice_id,
      id: account_choice_id,
      position: position,
      icon_id: meta[:icon_id],
      default: default,
      deleted: deleted
    }
  end
end
