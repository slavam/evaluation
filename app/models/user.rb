class User < ActiveRecord::Base
  acts_as_authentic do |c|
    c.ignore_blank_passwords = false
  end

  def admin?
    role_id == 1
  end

end
