# #To make sure it lands after SDP

ActiveRecord::Base.send(:include, AfterCommit::ActiveRecord)
ActiveRecord::Base.include_after_commit_extensions