module Admin::EmailConfig::Utils
  # This method uses send grid api to remove the supplied email from send grid bounce list
  def remove_bounced_email(bounced_email_addr)
    send_grid_credentials = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
    Rails.logger.debug "Start remove_bounced_email #{bounced_email_addr}"
    begin
      unless bounced_email_addr.blank? || send_grid_credentials.blank?
        send_grid_response = HTTParty.get("https://sendgrid.com/api/bounces.delete.xml?api_user=#{send_grid_credentials[:user_name]}&api_key=#{send_grid_credentials[:password]}&email=#{bounced_email_addr}", {})
        send_grid_res_hash = Hash.from_xml(send_grid_response)
        result_msg = send_grid_res_hash['result'] || send_grid_res_hash['errors'] unless send_grid_res_hash.nil?
      end
      Rails.logger.info "Removing email id #{bounced_email_addr} from send grid bounced list resulted in #{result_msg}"
    rescue StandardError => e
      Rails.logger.error("Error during removal of bounced email #{bounced_email_addr} from send grid. \n#{e.message}\n#{e.backtrace.join("\n")}")
    end
  end
end
