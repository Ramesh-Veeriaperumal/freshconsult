class Mobihelp::App < ActiveRecord::Base

  validates_presence_of :name
  validates_inclusion_of :platform, :in => PLATFORM_ID_BY_KEY.values

end
