require 'core_ext/method_missing.rb'

ActiveSupport::CoreExtensions::Hash::Conversions::XML_PARSING.delete('symbol')
ActiveSupport::CoreExtensions::Hash::Conversions::XML_PARSING.delete('yaml')