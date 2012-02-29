class User < ActiveRecord::Base
  belongs_to :role
  acts_as_authentic do |c|
    c.ignore_blank_passwords = false
  end

  def admin?
    role_id == 1
  end

  def calculator?
    role_id == 2
  end
end
