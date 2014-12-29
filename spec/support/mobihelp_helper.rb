require 'base64'

module MobihelpHelper

  def create_mobihelp_user(test_account=nil, email_id, device_id)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    mh_app = create_mobihelp_app

    @mh_user = User.find_by_email(email_id) unless email_id.nil?
    return @mh_user unless @mh_user.nil?

    @mh_user = Factory.build(:user, :account => account, :email => email_id,
                              :user_role => 3)
    @mh_user.save
    Rails.logger.debug("Created user #{@mh_user.inspect}");

    create_user_device(mh_app, @mh_user, device_id);
    @mh_user
  end

  def create_mobihelp_app
    mh_app = Factory.build(:mobihelp_app, :name => "Fresh App #{Time.now.nsec}")
    mh_app.save
    Rails.logger.debug("Created mobihelp_app #{mh_app.inspect}");
    mh_app
  end

  def create_user_device(app, user, device_id)
    @mh_device = user.mobihelp_devices.find_by_device_uuid(device_id)
    return @mh_device unless @mh_device.nil?

    @mh_device = Factory.build(:mobihelp_device, :user_id => user.id , :app_id => app.id , :device_uuid => device_id)
    @mh_device.save
    Rails.logger.debug("Created mobihelp_device #{@mh_device.inspect}");
    @mh_device
  end

  def create_mobihelp_ticket(params = {})
    @mh_ticket = Factory.build(:mobihelp_ticket, :subject => params[:helpdesk_ticket][:subject], 
     :external_id => params[:helpdesk_ticket][:external_id], :requester_id => params[:helpdesk_ticket][:requester_id],
     :ticket_body_attributes => params[:helpdesk_ticket][:ticket_body_attributes], 
     :mobihelp_ticket_info_attributes => params[:helpdesk_ticket][:mobihelp_ticket_info_attributes]) 
    @mh_ticket.save
    Rails.logger.debug("Created mobihelp_ticket #{@mh_ticket.inspect}");
    @mh_ticket
  end

  def create_mobihelp_ticket_extras(ticket_id, account_id)
    @mh_ticket_extras = Factory.build(:mobihelp_ticket_extras)
    @mh_ticket_extras.ticket_id = ticket_id
    @mh_ticket_extras.account_id = account_id
    @mh_ticket_extras.save
  end

  def create_mobihelp_app_solutions(params = {})
    @mh_solutions = Factory.build(:mobihelp_app_solutions, :app_id => params[:app_id], :category_id => params[:category_id], :position => params[:position], :account_id => params[:account_id])
    @mh_solutions.save
    Rails.logger.debug("Created mobihelp app solutions : #{@mh_solutions}")
    @mh_solutions
  end

  def get_app_auth_key(app)
    Base64.encode64("#{app.app_key}:#{app.app_secret}");
  end

  def get_sample_mobihelp_ticket_attributes(subject, device_uuid, user)
    {
      :helpdesk_ticket => {
        :source => 8,
        :subject => subject,
        :external_id => device_uuid,
        :requester_id => user.id,
        :ticket_body_attributes => { :description_html => "<p>Testing</p>"},
        :mobihelp_ticket_info_attributes =>  {
          :device_id => user.mobihelp_devices.find_by_device_uuid(device_uuid).id,
          :app_name => "MyApp",
          :app_version => "1.4(12)",
          :os => "ANDROID",
          :os_version => "4.4",
          :sdk_version => "1.0",
          :device_make => "Samsung",
          :device_model => "I9031",
          :debug_data => {
            :resource => Rack::Test::UploadedFile.new('spec/fixtures/mobihelp_extra_complete.json', 'text/plain')
          }
        }
      }
    }
  end
end
