class Helpdesk::Choice < ActiveRecord::Base
  self.table_name = 'helpdesk_choices'
  scope :ordered, -> { order(:position) }

  scope :visible, -> { where(deleted: false) }
  scope :custom, -> { where(default: false) }
  scope :default, -> { where(default: true) }

  acts_as_list scope: [:account_id, :type]

  attr_accessible :name, :position, :default, :deleted, :account_choice_id, :type, :meta

  validates :account_choice_id, uniqueness: { scope: [:account_id, :type] }
  validates :type, presence: true
end
