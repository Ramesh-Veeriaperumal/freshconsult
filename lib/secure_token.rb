module SecureToken
  def self.generate
    "#{SecureRandom.uuid}-#{SecureRandom.hex(4)}"
  end
end