module IntegrationServices::Services
  module Office365
    class EmailResource < Office365Resource

      def send_email options
        Office365Mailer.email_to_outlook(options)
      end

    end
  end
end





