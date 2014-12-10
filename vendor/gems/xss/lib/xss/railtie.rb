module Xss
  class Railtie < Rails::Railtie
    initializer "Xss.configure_rails_initialization" do
      # some initialization behavior
      require 'html_sanitizer'
      require 'rails_sanitizer'
      ActiveRecord::Base.send(:include, HtmlSanitizer)
    end
  end
end