module PaypalPayments

  SANDBOX_PAYPAL_URL = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token='

  ACCESS_TOKENS = ['EC-3SE376902L8567302', 'EC-3KC43526H78377427', 'EC-1WE41630LH248660U', 'EC-4MN16516BJ340251P', 'EC-0FR73206N00060043'].freeze

  def payment_url
    return (SANDBOX_PAYPAL_URL + ACCESS_TOKENS.sample) unless Rails.env.development?
    gateway = ActiveMerchant::Billing::PaypalExpressGateway.new(paypal_express_params)
    response = gateway.setup_purchase(100, setup_hash)
    return gateway.redirect_url_for(response.token)
  end

  def paypal_express_params
    paypal_express_params = {
      login: 'sb-cs6gz3944576_api1.business.example.com',
      password: 'H8GNBVCFRHMAKFDM',
      signature: 'AmSVex3LJCKk-l53EOhlhMlR6AkKAWMQUji6YUzGIdEN6rhI-0xFk-9L'
    }
  end

  def setup_hash
    {
      items: [{name: 'Order', quantity: 1, amount: 100, description: 'desc'}],
      subtotal: 100,
      shipping: 0,
      handling: 0,
      tax: 0,
      currency: 'INR',
      allow_guest_checkout: true,
      return_url: 'www.google.com',
      cancel_return_url: 'www.google.com'
    }
  end
end
