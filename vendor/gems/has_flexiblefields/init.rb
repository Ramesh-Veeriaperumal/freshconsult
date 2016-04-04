ActiveRecord::Base.send :include, Has::FlexibleFields

# This plugin should be reloaded in development mode.
if Rails.env.development?
  ActiveSupport::Dependencies.autoload_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end
