require File.dirname(__FILE__) + "/../../lib/spam_watcher/spam_watcher_callbacks"
ActiveRecord::Base.send(:include,SpamWatcherCallbacks)
