class SolutionPlatformMapping < ActiveRecord::Base
  self.primary_key = :id

  belongs_to_account
  belongs_to :mappable, polymorphic: true

  attr_accessible :web, :ios, :android
end
