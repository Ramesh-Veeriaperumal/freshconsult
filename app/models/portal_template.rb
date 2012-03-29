class PortalTemplate < ActiveRecord::Base
  belongs_to :account
  belongs_to :portal
  
  has_many :portal_pages, :dependent => :destroy
end
