class ReportsController < ApplicationController
  before_filter { |c| c.requires_permission :manage_users }
  
  include Reports::ConstructReport
  
  def index
   @global_hash_agts = build_tkts_hash("responder")
   @global_hash_grps = build_tkts_hash("group")
  end
 
 protected
 
 def scoper
   current_account
 end
  
end