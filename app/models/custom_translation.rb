# This model is used to add translations for custom fields, surveys and etc.
class CustomTranslation < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = 'custom_translations'
  serialize :translations, Hash
  belongs_to :translatable, polymorphic: true
  belongs_to_account
  attr_accessible :language_id, :translations, :translatable_id, :translatable_type
end