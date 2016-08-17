namespace :seed_sample do
  desc "This task creates mobihelp tickets"
  task :mobihelp_tickets, [:account_id] => :environment do |t, args|
    account_id = args[:account_id] || ENV["ACCOUNT_ID"] || Account.first.id
    Sharding.select_shard_of(account_id) do 
      account = Account.find(account_id).make_current
      define_mobihelp_factories
      @user = create_mobihelp_user
      (rand(2..10)).times do
        create_mobihelp_ticket
      end
      Account.reset_current_account
    end
  end

  def define_mobihelp_factories
    FactoryGirl.define do
      factory :user do
        name Faker::Name.name
        time_zone "Chennai"
        active 1
        user_role 1
        phone Faker::PhoneNumber.phone_number
        mobile Faker::PhoneNumber.phone_number
        crypted_password "5ceb256c792bcf9dab05c8a00775fc13b42a6abd516f130acd76ab81af046d49a1fc5062bec4f27b77580348de6d8c510c7ff6b29f720694ff39a5bfd69c604d"
        single_access_token Faker::Lorem.characters(19)
        password_salt "Hd8iUst0Jr5TWnulZhgf"
        persistence_token Faker::Lorem.characters(127)
        delta 1
        language "en"
      end
      
      factory :mobihelp_app, class: Mobihelp::App do |t|
        name "Fresh App"
        platform 1
        config HashWithIndifferentAccess.new({ bread_crumbs: Mobihelp::App::DEFAULT_BREADCRUMBS_COUNT, debug_log_count: Mobihelp::App::DEFAULT_LOGS_COUNT, app_review_launch_count: Mobihelp::App::DEFAULT_APP_REVIEW_LAUNCH_COUNT})
      end

      factory :mobihelp_device, class: Mobihelp::Device do |t|
        app_id 1
        user_id 1
        device_uuid "1123-123123-123123123"
      end
    end
  end

  def device_id
    @user_device_id ||= Faker::Number.number(20)
  end

  def create_mobihelp_user
    mh_app = create_mobihelp_app
    email_id = Faker::Internet.email
    mh_user = User.find_by_email(email_id)
    if mh_user.nil?
      mh_user = FactoryGirl.build(:user, email: email_id, user_role: 3)
      mh_user.save
    end
    create_user_device(mh_app, mh_user)
    mh_user
  end

  def create_mobihelp_app(params = {})
    mh_app = Account.current.mobihelp_apps.first
    return mh_app unless mh_app.nil?
    mh_app = FactoryGirl.build(:mobihelp_app, name: "Fresh App #{Time.now.nsec}")
    mh_app.save
    mh_app
  end

  def create_user_device(app, user)
    mh_device = user.mobihelp_devices.find_by_device_uuid(device_id)
    return mh_device unless mh_device.nil?
    mh_device = FactoryGirl.build(:mobihelp_device, user_id: user.id , app_id: app.id , device_uuid: device_id)
    mh_device.save
    mh_device
  end

  def create_mobihelp_ticket
    params = mobihelp_ticket_params
    ticket = Account.current.tickets.build(params[:ticket])
    ticket.save_ticket
    create_tag(ticket, params[:ticket][:mobihelp_ticket_info_attributes][:app_name])
    store_debug_logs(ticket, params[:ticket][:mobihelp_ticket_info_attributes][:debug_data])
  end

  def create_tag ticket, tag_name
      tag = Account.current.tags.find_by_name(tag_name) || Account.current.tags.create(name: tag_name)
      ticket.tags << tag
  end

  def store_debug_logs ticket, debug_data
    mobihelp_ticket_info = ticket.mobihelp_ticket_info
    mobihelp_ticket_info.create_debug_data(content: debug_data[:resource], description: debug_data[:description])
  end

  def mobihelp_ticket_params
    {
      ticket: {
        source: 8,
        subject: Faker::Lorem.sentence(3),
        external_id: device_id,
        requester_id: @user.id,
        ticket_body_attributes: { description_html: Faker::Lorem.paragraph },
        mobihelp_ticket_info_attributes:  {
          device_id: @user.mobihelp_devices.find_by_device_uuid(device_id).id,
          app_name: Faker::App.name,
          app_version: Faker::App.version,
          os: "ANDROID",
          os_version: Faker::App.version,
          sdk_version: Faker::App.version,
          device_make: "Samsung",
          device_model: "I9031",
          debug_data: {
            resource: Rack::Test::UploadedFile.new('db/sample_data/mobihelp_debug_data.json', 'text/plain')
          }
        }
      }
    }
  end
end