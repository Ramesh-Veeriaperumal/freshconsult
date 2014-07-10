require 'spec_helper'

describe Support::SignupsController do

  it "should not create a new user" do
    post :create, :user => { :email => "" }
    response.should render_template 'support/signups/new.portal'
  end

  it "should not create a new user with an invalid email" do
    post :create, :user => { :email => Faker::Lorem.sentence }
    response.should render_template 'support/signups/new.portal'
  end
end