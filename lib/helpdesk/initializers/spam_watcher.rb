require "#{Rails.root}/lib/spam_watcher/spam_watcher_callbacks"
ActiveRecord::Base.send(:include,SpamWatcherCallbacks)
