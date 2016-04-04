# encoding: utf-8
require 'digest/md5'

class Helpdesk::SpamTicket < Helpdesk::Mysql::DynamicTable
  self.abstract_class = true
  belongs_to_account
  belongs_to :requester, :class_name => 'User'
  
  has_many_attachments
  has_many_cloud_files
  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable', :dependent => :destroy
  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :survey_results, :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  has_many :time_sheets, :class_name => 'Helpdesk::TimeSheet',:as => 'workable',:dependent => :destroy, :order => "executed_at"
  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy
  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'

  serialize :associations_data
  attr_protected :account_id

  def spam_notes
    Helpdesk::SpamNote.find_all(:conditions => ["account_id = ? and spam_ticket_id = ?",self.account_id,self.id], :order => "id desc")
  end

  def destroy_spam_notes
    Helpdesk::SpamNote.destroy_all({:account_id => self.account_id, :spam_ticket_id => self.id})
  end
  
end