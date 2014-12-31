require 'spec_helper'

RSpec.describe "SpamWatcher" do
  self.use_transactional_fixtures = false
  before(:all) do
    load "tasks/spam_watcher_redis.rake"
    Rake::Task.define_task(:environment)
  end

  before(:each) do
    @account.make_current
    @agent1 = add_agent_to_account(@account, {:name => "testing45", :email => Faker::Internet.email,
                                              :active => 1, :role => 1
                                              })
    @user1 = add_new_user(@account)
    FreshdeskErrorsMailer.stubs(:deliver_spam_watcher).returns("email delivered")
    SubscriptionNotifier.stubs(:deliver_admin_spam_watcher).returns("email delivered")
  end

  after(:each) do
    @account.make_current #Account reset in core_spam_watcher
    @agent1.destroy
    @user1.destroy
    # Account.reset_current_account
  end

  describe "tickets" do
    context "agent belongs to paid account" do
      it "delete the agent and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @agent1.user.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.deleted.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        @agent1.user.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.deleted.should eql false
      end
    end
    context "agent belongs to unpaid account" do
      it "block the agent if free account and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        Subscription.any_instance.stubs(:state).returns("free")
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql true
      end
      it "block the agent if trial account and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        Subscription.any_instance.stubs(:state).returns("trial")
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql false
      end
    end

    context "customer belongs to paid account" do
      it "delete the customer and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.deleted.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.deleted.should eql false
      end
    end

    context "customer belongs to unpaid account" do
      it "block the customer and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("free")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.blocked.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("free")
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.blocked.should eql false
      end
    end


  end

  describe "creation of ticket should push into the queue" do
    it "pushing into the queue" do
      $spam_watcher.rpush("sw_helpdesk_tickets:#{@account.id}:#{@user1.id}",(Time.now+10.minutes).to_i)
      $spam_watcher.rpush(SpamConstants::SPAM_WATCHER_BAN_KEY,"sw_helpdesk_tickets:#{@account.id}:#{@user1.id}")
      $spam_watcher.stubs(:rpush).returns(SpamConstants::SPAM_WATCHER["helpdesk_tickets"]["threshold"])
      @ticket =  Helpdesk::Ticket.new(
        :requester_id => @user1.id,
        :subject => "test note one",
        :ticket_body_attributes => {
          :description => "test",
          :description_html => "<div>test</div>"
        },
        :account_id => @account.id 
      )
      @ticket.save_ticket
      $spam_watcher.rpop(SpamConstants::SPAM_WATCHER_BAN_KEY).should eql "sw_helpdesk_tickets:#{@account.id}:#{@user1.id}"
    end
  end

  describe "notes" do
    context "agent belongs to paid account" do
      it "delete the agent and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @agent1.user.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.deleted.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_tickets:#{@account.id}:#{@agent1.user_id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        @agent1.user.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.deleted.should eql false
      end
    end
    context "agent belongs to unpaid account" do
      it "block the agent if free account and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        Subscription.any_instance.stubs(:state).returns("free")
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql true
      end
      it "block the agent if trial account and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        Subscription.any_instance.stubs(:state).returns("trial")
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@agent1.user_id}"])
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        @agent1.user.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@agent1.user_id,@account.id)
        user.blocked.should eql false
      end
    end

    context "customer belongs to paid account" do
      it "delete the customer and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.deleted.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("active")
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.deleted.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.deleted.should eql false
      end
    end

    context "customer belongs to unpaid account" do
      it "block the customer and send email" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("free")
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.blocked.should eql true
      end
      it "skip if the user is whitelisted" do
        Redis.any_instance.stubs(:blpop).returns(["spam_watcher_queue", "sw_helpdesk_notes:#{@account.id}:#{@user1.id}"])
        Subscription.any_instance.stubs(:state).returns("free")
        WhitelistUser.stubs(:find_by_account_id_and_user_id).returns(true)
        # Rake::Task["spam_watcher_redis:block_spam_user"].invoke
        @user1.blocked.should eql false
        core_spam_watcher
        user = User.find_by_id_and_account_id(@user1.id,@account.id)
        user.blocked.should eql false
      end
    end

    describe "creation of ticket should push into the queue" do
    it "pushing into the queue" do
      $spam_watcher.rpush("sw_helpdesk_notes:#{@account.id}:#{@user1.id}",(Time.now+10.minutes).to_i)
      $spam_watcher.rpush(SpamConstants::SPAM_WATCHER_BAN_KEY,"sw_helpdesk_notes:#{@account.id}:#{@user1.id}")
      @ticket =  Helpdesk::Ticket.new(
        :requester_id => @user1.id,
        :subject => "test note one",
        :ticket_body_attributes => {
          :description => "test",
          :description_html => "<div>test</div>"
        },
        :account_id => @account.id 
      )
      @ticket.save_ticket
      note = @ticket.notes.build(
          :user_id => @user1.id
      )
      $spam_watcher.stubs(:rpush).returns(SpamConstants::SPAM_WATCHER["helpdesk_notes"]["threshold"])
      note.save_note
      $spam_watcher.rpop(SpamConstants::SPAM_WATCHER_BAN_KEY).should eql "sw_helpdesk_notes:#{@account.id}:#{@user1.id}"
    end
  end

    # context "bulk reply" do
    #   it "should not block if the user is doing bulk action" do
    #   end
    #   it "should remove the key once the job is processed" do
    #   end
    # end
  end
end
