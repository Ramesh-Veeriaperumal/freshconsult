# This model is used to add translations for custom fields, surveys and etc.
class CustomTranslation < ActiveRecord::Base
  include DataVersioning::Model

  self.primary_key = :id
  self.table_name = 'custom_translations'
  serialize :translations, Hash
  belongs_to :translatable, polymorphic: true
  belongs_to_account
  attr_accessible :language_id, :translations, :translatable_id, :translatable_type
  clear_memcache [TICKET_FIELDS_FULL]

  VERSION_MEMBER_KEYS = {
    'Helpdesk::TicketField' => "#{Helpdesk::TicketField::VERSION_MEMBER_KEY}:TRANSLATION:%{language_code}"
  }.freeze

  def custom_version_entity_key
    format(VERSION_MEMBER_KEYS['Helpdesk::TicketField'], language_code: language_code)
  end

  def language_code
    @language_code ||= Language.find(language_id).try(:code)
  end
end