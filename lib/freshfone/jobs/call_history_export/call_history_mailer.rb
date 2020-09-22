module Freshfone::Jobs
  module CallHistoryExport
    class CallHistoryMailer < ActionMailer::Base
        
      layout "email_font"
      include EmailHelper

      def call_history_export(options={})
        headers = get_headers(options[:user].email, options[:user])
        headers[:subject] = get_subject options
        initialize_variables options
        mail(headers) do | part|
          options[:url].blank? ? part.html { render "no_records", :formats => [:html] } :
            part.html { render "call_history_export", :formats => [:html] }
        end.deliver
      end

      private
        def get_headers(email, user)
          headers = {
            :to                         => email,
            :from                       => AppConfig['from_email'],
            :bcc                        => "reports@freshdesk.com",
            :sent_on                    => Time.now,
            "Reply-to"                  => "",
            "Auto-Submitted"            => "auto-generated", 
            "X-Auto-Response-Suppress"  => "DR, RN, OOF, AutoReply"
          }

          headers.merge!(make_header(nil, nil, user.account_id, "Call history Export"))
        end

        def get_subject options
          if options[:url].blank?
            I18n.t('export_data.call_history.no_records_mail.subject', :range => JSON.parse(options[:export_params][:data_hash])[0]["value"])
          else
            formatted_export_subject(options)
          end
        end

        def formatted_export_subject(options)
          I18n.t('export_data.call_history.subject',
            :number => @number,
            :range => JSON.parse(options[:export_params][:data_hash])[0]["value"], # Shows date range
            :domain => options[:domain]
            )
        end

        def initialize_variables params
          @url = params[:url]
          @user = params[:user]

          data_hash = JSON.parse(params[:export_params][:data_hash])
          find_value_of = lambda do |condition|
            hash_item = data_hash.find { |entry| entry["condition"] == condition }
            hash_item.blank? ? nil : hash_item["value"]
          end
          
          @number = params[:number] == 0 ? t('reports.freshfone.all_numbers') : params[:number]

          @range = find_value_of.call("created_at")
          @call_type = find_value_of.call("call_type")
          @agent = params[:account].users.find_by_id(find_value_of.call("user_id"))
          @requester = params[:account].customers.find_by_id(find_value_of.call("customer_id"))
          @group = params[:account].groups.find_by_id(find_value_of.call("group_id"))
        end

      # TODO-RAILS3 Can be removed oncewe fully migrate to rails3
      # Keep this include at end
      include MailerDeliverAlias
    end
  end
end
