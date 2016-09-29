module AccountCleanup
  module Common

    def clean_attachments(args)
      account = Account.current
      begin
        while true    
          if args[:attachable_ids]
            attachable_ids = args[:attachable_ids]
            attachable_types = args[:attachable_type]
          # find attachment ids using attachable ids
            query = "select id from helpdesk_attachments where account_id = #{account.id} and attachable_id in (#{attachable_ids.join(',')}) and attachable_type in ('#{attachable_types.join("','")}') LIMIT 50"
          else  
            # only account id
            query = "select id from helpdesk_attachments where account_id = #{account.id} limit 50"
          end
          puts query
          attachment_ids = ActiveRecord::Base.connection.select_values(query)
          break if attachment_ids.size == 0
          objects = []
          bucket = S3_CONFIG[:bucket]
          attachment_ids.each do |attachment_id|
            prefix = "data/helpdesk/attachments/#{Rails.env}/#{attachment_id}/"
            begin
              attachment_objects = AwsWrapper::S3Object.find_with_prefix(bucket,prefix)
              attachment_objects.each do |o| 
                objects << o
              end
            rescue Exception => e
                puts e
            end
          end
          AWS::S3::Bucket.new(bucket).objects.delete(objects) # Batch deletion 
          delete_query = "delete from helpdesk_attachments where id in (#{attachment_ids.join(",")}) and account_id = #{account.id}"
          puts delete_query
          ActiveRecord::Base.connection.execute(delete_query)
        end
      rescue Exception => e
        puts e
        NewRelic::Agent.notice_error(e, :description => "Unable to perform attachments deletion for account: #{account.id}, #{account.full_domain}")
      end
    end

  end
end
