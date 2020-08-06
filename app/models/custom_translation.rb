# This model is used to add translations for custom fields, surveys and etc.
class CustomTranslation < ActiveRecord::Base
  include DataVersioning::Model
  include Cache::FragmentCache::Base

  self.primary_key = :id
  self.table_name = 'custom_translations'
  serialize :translations, Hash
  belongs_to :translatable, polymorphic: true
  belongs_to_account
  scope :only_ticket_fields, -> { where(translatable_type: 'Helpdesk::TicketField') }
  
  attr_accessible :language_id, :translations, :translatable_id, :translatable_type, :status
  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]
  after_commit :clear_fragment_caches

  SURVEY_STATUS = {
    untranslated: 0,
    translated: 1,
    outdated: 2,
    incomplete: 3
  }.freeze

  SURVEY_STATUS.keys.each do |k|
    define_method "mark_#{k}" do
      self.status = SURVEY_STATUS[k]
    end
  end

  VERSION_MEMBER_KEYS = {
    'Helpdesk::TicketField' => "#{Helpdesk::TicketField::VERSION_MEMBER_KEY}:TRANSLATION:%{language_code}"
  }.freeze

  def custom_version_entity_key
    format(VERSION_MEMBER_KEYS['Helpdesk::TicketField'], language_code: language_code)
  end

  def language_code
    @language_code ||= Language.find(language_id).try(:code)
  end

  def sanitize_and_update(uploaded_translations)
    mark_translated
    custom_translation = translations
    presenter_hash = translatable.as_api_response(:custom_translation).stringify_keys

    self.translations = update_and_merge(presenter_hash, uploaded_translations, custom_translation)
  end

  def update_and_merge(presenter_hash, uploaded_translations, custom_translation)
    translated_hash = {}
    presenter_hash.each_key do |key, value|
      if presenter_hash[key].is_a?(Hash)
        t_hash = uploaded_translations && uploaded_translations[key].present? ? uploaded_translations[key] : nil
        ct_hash = custom_translation && custom_translation[key].present? ? custom_translation[key] : nil
        if (t_hash || ct_hash) && ( uploaded_translations.blank? || uploaded_translations[key] != '' )
          translated_hash[key] = update_and_merge(presenter_hash[key], t_hash, ct_hash)
        else
          # User explicitly deletes any keys
          mark_incomplete
        end
      else
        # Update & Merge done here.
        set_translated_hash(translated_hash, key, uploaded_translations, custom_translation)
      end
    end
    translated_hash
  end

  def set_translated_hash(translated_hash, key, uploaded_translations, custom_translation)
    translated_hash[key] = (uploaded_translations && uploaded_translations[key]) || (custom_translation && custom_translation[key])
    if translated_hash[key].blank?
      mark_incomplete
      translated_hash.delete(key)
    end
  end
end
