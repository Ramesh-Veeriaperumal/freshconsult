namespace :seed_sample do


  require "#{Rails.root}/spec/support/freshfone_spec_helper.rb"
  include FreshfoneSpecHelper

  desc 'Create a ticket with an associated phone conversation'
  # usage rake fone_ticket:create['/Users/user/songs/sample.mp3',25,1,1]
  # duration should be in seconds
  task :fone_ticket, [:audio_filepath, :duration, :account_id, :user_id] => :environment do |t, args|
    select_the_shard(*account_user_info(args)) do
      @file_url = args[:audio_filepath]
      @duration = args[:duration]
      new_fone_call
      ticket_from_call
    end
  end

  desc 'Create a ticket with an associated phone conversation'
  # usage rake fone_ticket:create[45,34,'/Users/user/songs/sample.mp3',25,1,1]
  # :ticket_id should be the display id of the ticket
  task :fone_call_to_note, [:ticket_id, :note_id, :audio_filepath, :duration, :account_id, :user_id] => :environment do |t, args|
    select_the_shard(*account_user_info(args)) do
      @file_url = args[:audio_filepath]
      @duration = args[:duration]
      new_fone_call
      add_call_to_note(args[:ticket_id], args[:note_id])
    end
  end

  def account_user_info(args)
    account_id = args[:account_id] || ENV['ACCOUNT_ID'] || Account.first.id
    user_id = args[:user_id] || ENV['USER_ID'] || Account.first.agents.first.user_id
    puts "Seeding fone tickets for Account ID : #{account_id}, User ID : #{user_id}"
    [account_id, user_id]
  end

  def select_the_shard(account_id, user_id)
    Sharding.select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      @agent = @account.agents.find_by_user_id(user_id).user.make_current
      yield
    end
  end

  def new_fone_call
    if @account.freshfone_account.present?
      @credit = @account.freshfone_credit
      @number ||= @account.freshfone_numbers.first
    else
      create_test_freshfone_account
    end
    @call = create_freshfone_call
    create_audio_attachment
  end

  def create_audio_attachment
    @file_url ||= "#{Rails.root}/spec/fixtures/files/callrecording.mp3"
    @data = File.open(@file_url)

    @call.update_attributes(recording_url: @file_url.gsub('.mp3', ''))
    @call.update_status({ DialCallStatus: 'voicemail' })
    
    @call.call_duration = @duration
    
    @call.build_recording_audio(content: @data).save
  end

  def ticket_from_call
    @ticket = create_portal_ticket
    associate_call_to_item(@ticket)
  end

  def associate_call_to_item(obj)
    @call.notable_id = obj.id
    @call.notable_type = obj.class.name
    @call.save
  end

  def add_call_to_note(ticket_id, note_id)
    (puts("Invalid ticket_id and note_id") and return) if ticket_id.blank? || note_id.blank?

    ticket = @account.tickets.find_by_display_id(ticket_id)
    note = ticket.notes.find_by_id(note_id)

    (puts("Invalid ticket_id and note_id") and return) if ticket.blank? || note.blank?
    associate_call_to_item(note)
  end

end