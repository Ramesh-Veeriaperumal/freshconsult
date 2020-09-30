class Helpdesk::Note < ActiveRecord::Base

	belongs_to_account

	belongs_to :notable, :polymorphic => true

  belongs_to :user

  has_many_attachments

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment",
                                :conditions => { :attachable_type => "Note::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy,
                                :before_add => :set_inline_attachable_type

  has_many_cloud_files

  has_one :tweet,
    :as => :tweetable,
    :class_name => 'Social::Tweet',
    :dependent => :destroy

  has_one :fb_post,
    :as => :postable,
    :class_name => 'Social::FbPost',
    :dependent => :destroy

  has_one :survey_remark, :foreign_key => 'note_id', :dependent => :destroy

  has_one :custom_survey_remark, :foreign_key =>'note_id', :class_name => 'CustomSurvey::SurveyRemark', :dependent => :destroy

  has_one :note_body, class_name: 'Helpdesk::NoteBody', dependent: :destroy
  accepts_nested_attributes_for :note_body, update_only: true

  has_one :schema_less_note, :class_name => 'Helpdesk::SchemaLessNote',
          :foreign_key => 'note_id', :autosave => true, :dependent => :destroy

  has_one :external_note, :class_name => 'Helpdesk::ExternalNote',:dependent => :destroy

  delegate :deleted, :company_id, :responder_id, :group_id, :spam, :requester_id, :to => :notable, :allow_nil => true, :prefix => true

  accepts_nested_attributes_for :tweet , :fb_post

  has_one :freshcaller_call, class_name: 'Freshcaller::Call', as: 'notable'

  has_one :ebay_question, :as => :questionable, :class_name => 'Ecommerce::EbayQuestion', :dependent => :destroy

  has_one :cti_call, :class_name => 'Integrations::CtiCall', :as => 'recordable', :dependent => :destroy

  has_one :broadcast_message, :class_name => 'Helpdesk::BroadcastMessage', :foreign_key =>'note_id',
          :dependent => :destroy

  belongs_to :note_source, class_name: 'Helpdesk::Source', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :notes

  private

  def set_inline_attachable_type(inline_attachment)
    inline_attachment.attachable_type = "Note::Inline"
  end
end
