require 'rails'

module Authority
  class Railtie < Rails::Railtie
    initializer "Authority", :after => "Authority" do
        require "#{::Rails.root}/config/privileges"
        require "authority/constants"
    end
  end
end