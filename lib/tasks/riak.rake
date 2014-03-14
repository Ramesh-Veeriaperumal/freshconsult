
namespace :riak do
  # usage rake riak:ticket_body[1,100,50]
  # this task is migrates ticket_body from helpdesk_ticket_bodies table to riak
  desc 'Migrate ticket body from mysql to riak'
  task :ticket_body, [:starting_id, :ending_id, :batch_size] => :environment do |task, args|
    shards = Sharding.all_shards
    shards.each do |shard_name|
      shard_sym = shard_name.to_sym
      puts "shard_name is #{shard_name}"
      Sharding.run_on_shard(shard_sym) do
        Helpdesk::TicketOldBody.find_in_batches(
          :batch_size => args[:batch_size].to_i,
          :conditions => ["id >= ? and id < ?",args[:starting_id].to_i,args[:ending_id].to_i]
        ) do |ticket_old_bodies|
          ticket_old_bodies.each do |ticket_old_body|
            data = {
              :ticket_body => {
                :description => ticket_old_body.description,
                :description_html => ticket_old_body.description_html,
                :raw_text => ticket_old_body.raw_text,
                :raw_html => ticket_old_body.raw_html,
                :meta_info => ticket_old_body.meta_info,
                :version => ticket_old_body.version,
                :account_id => ticket_old_body.account_id,
                :created_at => ticket_old_body.created_at,
                :updated_at => ticket_old_body.updated_at,
                :ticket_id => ticket_old_body.ticket_id
              }
            }
            obj = $ticket_body.get_or_new("#{ticket_old_body.account_id}/#{ticket_old_body.ticket_id}")
            unless obj.data
              obj.data = data
              obj.store
            end
          end
        end
      end
    end
  end

  # usage rake riak:note_body[1,100,50]
  # this task is used to migrate note_body from helpdesk_note_bodies table to riak
  desc 'Migrate note body from mysql helpdesk note body to riak'
  task :note_body, [:starting_id, :ending_id, :batch_size] => :environment do |task, args|
    shards = Sharding.all_shards
    shards.each do |shard_name|
      shard_sym = shard_name.to_sym
      puts "shard_name is #{shard_name}"
      Sharding.run_on_shard(shard_sym) do
        Helpdesk::NoteOldBody.find_in_batches(
          :batch_size => args[:batch_size].to_i,
          :conditions => ["id >= ? and id < ?",args[:starting_id].to_i,args[:ending_id].to_i]
        ) do |note_old_bodies|
          note_old_bodies.each do |note_old_body|
            data = {
              :note_body => {
                :body => note_old_body.body,
                :body_html => note_old_body.body_html,
                :full_text => note_old_body.full_text,
                :full_text_html => note_old_body.full_text_html,
                :raw_text => note_old_body.raw_text,
                :raw_html => note_old_body.raw_html,
                :meta_info => note_old_body.meta_info,
                :version => note_old_body.version,
                :account_id => note_old_body.account_id,
                :created_at => note_old_body.created_at,
                :updated_at => note_old_body.updated_at,
                :note_id => note_old_body.note_id,
              }
            }
            obj = $note_body.get_or_new("#{note_old_body.account_id}/#{note_old_body.note_id}")
            unless obj.data
              obj.data = data
              obj.store
            end
          end
        end
      end
    end
  end

  # usage rake riak:note[1,100,50]
  # this task is used to migrate note_body from helpdesk_notes table to riak
  desc 'Migrate note body from mysql helpdesk note to riak'
  task :note, [:starting_id, :ending_id, :batch_size] => :environment do |task, args|
    shards = Sharding.all_shards
    shards.each do |shard_name|
      shard_sym = shard_name.to_sym
      puts "shard_name is #{shard_name}"
      Sharding.run_on_shard(shard_sym) do
        Helpdesk::Note.find_in_batches(
          :batch_size => args[:batch_size].to_i,
          :conditions => ["id >= ? and id < ?",args[:starting_id].to_i,args[:ending_id].to_i]
        ) do |notes|
          notes.each do |note_old_body|
            data = {
              :note_body => {
                :body => note_old_body.body,
                :body_html => note_old_body.body_html,
                :full_text => note_old_body.body,
                :full_text_html => note_old_body.body_html,
                :raw_text => note_old_body.raw_text,
                :raw_html => note_old_body.raw_html,
                :meta_info => note_old_body.meta_info,
                :version => note_old_body.version,
                :account_id => note_old_body.account_id,
                :created_at => note_old_body.created_at,
                :updated_at => note_old_body.updated_at,
                :note_id => note_old_body.note_id
              }
            }
            obj = $note_body.get_or_new("#{note_old_body.account_id}/#{note_old_body.id}")
            unless obj.data
              obj.data = data
              obj.store
            end
          end
        end
      end
    end
  end
end