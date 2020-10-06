class Helpdesk::Source < Helpdesk::Choice
  concerned_with :associations, :constants, :validations, :callbacks, :presenter

  publishable on: [:create, :update]

  serialize :meta, HashWithIndifferentAccess

  SOURCE_FORMATTER = {
    all_ids: proc { source_from.map(&:account_choice_id) },
    keys_by_token: proc { source_from.map { |choice| [choice.try(:[], :from_constant) ? choice.translated_name : choice.translated_source_name(translation_record_from_ticket_fields), choice.account_choice_id] } },
    token_by_keys: proc { Hash[*source_from.map { |choice| [choice.account_choice_id, choice.default ? SOURCE_TOKENS_BY_KEY[choice.account_choice_id] : choice.name] }.flatten] }
  }.freeze

  private_constant :SOURCE_FORMATTER

  class << self
    def ticket_source_keys_by_token
      if Account.current && Account.current.launched?(:whatsapp_ticket_source)
        SOURCE_KEYS_BY_TOKEN
      else
        SOURCE_KEYS_BY_TOKEN.except(:whatsapp)
      end
    end

    def default_ticket_source_token_by_key
      if Account.current && Account.current.launched?(:whatsapp_ticket_source)
        SOURCE_TOKENS_BY_KEY
      else
        SOURCE_TOKENS_BY_KEY.except(13)
      end
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
      ret_hash = {
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
      ret_hash[ticket_source_keys_by_token[:whatsapp]] = note_source_keys_by_token['whatsapp'] if ticket_source_keys_by_token[:whatsapp].present?
      ret_hash
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
      if revamp_enabled?
        visible_sources.map(&:account_choice_id) - API_CREATE_EXCLUDED_VALUES
      else
        ticket_source_keys_by_token.slice(:email, :portal, :phone, :twitter, :facebook, :chat, :mobihelp, :feedback_widget, :ecommerce).values
      end
    end

    def api_unpermitted_sources_for_update
      if Account.current && Account.current.launched?(:whatsapp_ticket_source)
        API_UPDATE_EXCLUDED_VALUES
      else
        API_UPDATE_EXCLUDED_VALUES - [13]
      end
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
      Hash[*ARCHIVE_NOTE_SOURCES.zip((0..ARCHIVE_NOTE_SOURCES.size - 1).to_a).flatten]
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
      if Account.current&.launched?(:whatsapp_ticket_source)
        TICKET_SOURCES
      else
        TICKET_SOURCES.reject { |i| i[0] == :whatsapp }
      end
    end

    def default_ticket_source_names_by_key
      if Account.current&.launched?(:whatsapp_ticket_source)
        SOURCE_NAMES_BY_KEY
      else
        SOURCE_NAMES_BY_KEY.except(13)
      end
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
