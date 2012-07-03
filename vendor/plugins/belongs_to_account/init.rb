require 'core_ext/active_record/default_scope_with_proc.rb'
require 'core_ext/active_record/association_preload.rb'


ActiveRecord::Base.send :include, BelongsToAccount

# This plugin should be reloaded in development mode.
if RAILS_ENV == 'development'
  ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end
