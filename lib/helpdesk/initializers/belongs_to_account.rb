# TODO-RAILS3 Its too bad need to check some other way for belongs_to_account
require File.dirname(__FILE__) + "/../../plugins/belongs_to_account/belongs_to_account"

ActiveRecord::Base.send :include, BelongsToAccount

# This plugin should be reloaded in development mode.
if Rails.env.development?
  ActiveSupport::Dependencies.autoload_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end
