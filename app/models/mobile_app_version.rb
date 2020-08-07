class MobileAppVersion < ActiveRecord::Base
  not_sharded
  scope :mobile_app, ->(app_version,mobile_type){
    where(['app_version = ? AND mobile_type = ?',app_version,mobile_type])
    .limit(1)
  }
end
