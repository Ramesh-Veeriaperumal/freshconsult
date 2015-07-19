class Helpdesk::Note < ActiveRecord::Base

	belongs_to_account

	belongs_to :notable, :polymorphic => true

  belongs_to :user

  has_many_attachments

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

  has_one :note_old_body, :class_name => 'Helpdesk::NoteOldBody', :dependent => :destroy, :autosave => false

  has_one :schema_less_note, :class_name => 'Helpdesk::SchemaLessNote',
          :foreign_key => 'note_id', :autosave => true, :dependent => :destroy

  has_one :external_note, :class_name => 'Helpdesk::ExternalNote',:dependent => :destroy

  delegate :deleted, :company_id, :responder_id, :group_id, :spam, :requester_id, :to => :notable, :allow_nil => true, :prefix => true

  accepts_nested_attributes_for :tweet , :fb_post

  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'

end