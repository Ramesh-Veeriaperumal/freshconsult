# Include hook code here
ActiveRecord::Base.send :include, HelpdeskAttachable
ActionController::Base.send :include, LimitExceedRescue
