class Helpdesk::Source < Helpdesk::Choice
  concerned_with :associations, :constants, :validations, :callbacks, :presenter

  publishable on: [:create, :update]

  serialize :meta, HashWithIndifferentAccess

  class << self
    def default_ticket_source_keys_by_token
      SOURCE_KEYS_BY_TOKEN
    end

    def default_ticket_source_token_by_key
      SOURCE_TOKENS_BY_KEY
    end

    def ticket_sources_for_language_detection
      [PORTAL, FEEDBACK_WIDGET]
    end

    def note_sources
      NOTE_SOURCES
    end

    def note_source_keys_by_token
      Hash[*NOTE_SOURCES.zip((0..NOTE_SOURCES.size - 1).to_a).flatten]
    end

    def ticket_note_source_mapping
      note_sources = note_source_keys_by_token
      ret_hash = {
        EMAIL => note_sources['email'],
        PORTAL => note_sources['email'],
        PHONE => note_sources['email'],
        FORUM => note_sources['email'],
        TWITTER => note_sources['twitter'],
        FACEBOOK => note_sources['facebook'],
        CHAT => note_sources['email'],
        BOT => note_sources['email'],
        MOBIHELP => note_sources['mobihelp'],
        FEEDBACK_WIDGET => note_sources['email'],
        OUTBOUND_EMAIL => note_sources['email'],
        ECOMMERCE => note_sources['ecommerce'],
        WHATSAPP => note_sources['whatsapp'],
        nil => note_sources['canned_form']
      }
      ret_hash
    end

    def note_source_names_by_key
      note_source_keys_by_token.invert
    end

    def note_activities_hash
      {
        TWITTER => 'twitter',
        note_source_keys_by_token['ecommerce'] => 'ecommerce'
      }
    end

    def api_sources
      if revamp_enabled?
        visible_sources.map(&:account_choice_id) - API_CREATE_EXCLUDED_VALUES
      else
        default_ticket_source_keys_by_token.slice(:email, :portal, :phone, :twitter, :facebook, :chat, :mobihelp, :feedback_widget, :ecommerce).values
      end
    end

    def api_unpermitted_sources_for_update
      API_UPDATE_EXCLUDED_VALUES
    end

    def note_exclude_sources
      NOTE_EXCLUDE_SOURCES
    end

    def note_blacklisted_thank_you_detector_note_sources
      note_sources = note_source_keys_by_token
      [
        note_sources['feedback'],
        note_sources['meta'],
        note_sources['summary'],
        note_sources['automation_rule_forward'],
        note_sources['automation_rule']
      ]
    end

    def archive_note_sources
      ARCHIVE_NOTE_SOURCES
    end

    def archive_note_source_keys_by_token
      Hash[*ARCHIVE_NOTE_SOURCES.zip((0..ARCHIVE_NOTE_SOURCES.size - 1).to_a).flatten]
    end

    def archive_note_ticket_note_source_mapping
      note_sources = note_source_keys_by_token
      {
        EMAIL => note_sources['email'],
        PORTAL => note_sources['email'],
        PHONE => note_sources['email'],
        FORUM => note_sources['email'],
        TWITTER => note_sources['twitter'],
        FACEBOOK => note_sources['facebook'],
        CHAT => note_sources['email'],
        MOBIHELP => note_sources['mobihelp'],
        FEEDBACK_WIDGET => note_sources['email']
      }
    end

    def archive_note_activities_hash
      {
        TWITTER => 'twitter'
      }
    end

    def default_ticket_sources
      TICKET_SOURCES
    end

    def default_ticket_source_names_by_key
      SOURCE_NAMES_BY_KEY
    end

    def visible_sources
      Account.current.ticket_source_from_cache.reject(&:deleted)
    end

    def revamp_enabled?
      Account.current.ticket_source_revamp_enabled?
    end

    def source_choices(type)
      SOURCE_FORMATTER[type].call
    end

    def source_from
      return all_records if Account.current && revamp_enabled?

      default_records
    end

    def visible_custom_sources
      Account.current.ticket_source_from_cache.select { |choice| !choice.default && !choice.deleted }
    end

    private

      def current_supported_language
        User.current.try(:supported_language) || Language.current.try(:to_key)
      end

      def ticket_fields
        @ticket_fields ||= Account.current.ticket_fields_only.where(field_type: 'default_source').first
      end

      def translation_record_from_ticket_fields
        @translation_record_from_ticket_fields ||= ticket_fields.safe_send("#{current_supported_language}_translation")
      end

      def all_records
        Account.current.ticket_source_from_cache
      end

      def default_records
        default_ticket_sources.map do |ch|
          OpenStruct.new(name: ch[0],
                         account_choice_id: ch[2],
                         position: ch[2],
                         meta: { 'icon_id' => ch[2] },
                         default: true,
                         deleted: false,
                         from_constant: true,
                         translated_name: I18n.t(ch[1]))
        end
      end
  end

  def new_response_hash
    {
      label: name
    }.merge(response_hash)
  end

  def new_translated_response_hash(translation_record)
    {
      label: translated_source_name(translation_record)
    }.merge(response_hash)
  end

  def translated_source_name(translation_record = nil)
    return translate_default_source_name if default

    translate_custom_source_name(translation_record)
  end

  private

    def response_hash
      {
        value: account_choice_id,
        id: account_choice_id,
        position: position,
        icon_id: meta[:icon_id],
        default: default,
        deleted: deleted
      }
    end

    def translate_custom_source_name(translation_record)
      return name if translation_record.blank? || translation_record.translations.blank? || translation_record.translations['choices'].blank?

      choice = translation_record.translations['choices'].select { |ch| ch["choice_#{account_choice_id}"] }
      choice.present? && choice["choice_#{account_choice_id}"].present? ? choice["choice_#{account_choice_id}"] : name
    end

    def translate_default_source_name
      I18n.t(Helpdesk::Source.default_ticket_source_names_by_key[account_choice_id])
    end
end
