module ActiveMerchant
  module Billing
    autoload :Gateway, 'active_merchant/billing/gateway'
        
    Dir[File.dirname(__FILE__) + '/gateways/*.rb'].each{|g| require g}
  end
end
