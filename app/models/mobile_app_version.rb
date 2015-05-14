class MobileAppVersion < ActiveRecord::Base
  # attr_accessible :title, :body
  not_sharded
  scope :mobile_app, lambda { |app_version,mobile_type| {
          :conditions => ['app_version = ? AND mobile_type = ?',app_version,mobile_type],
          :limit => 1
        }
      }
      
end
