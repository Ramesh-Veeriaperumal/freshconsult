require 'core_ext/method_missing.rb'

#https://groups.google.com/forum/#!topic/rubyonrails-security/61bkgvnSGTQ/discussion

ActiveSupport::CoreExtensions::Hash::Conversions::XML_PARSING.delete('symbol')
ActiveSupport::CoreExtensions::Hash::Conversions::XML_PARSING.delete('yaml')