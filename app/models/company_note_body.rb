class CompanyNoteBody < ActiveRecord::Base
  self.primary_key = :id
  belongs_to_account
  belongs_to :company_note

  attr_accessible :body

  validates :body, presence: true
end
