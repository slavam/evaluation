class User < ActiveRecord::Base
  belongs_to :role
  acts_as_authentic do |c|
    c.ignore_blank_passwords = false
  end

#  acts_as_audited :except => [ :persistence_token,
#    :perishable_token, :login_count, :failed_login_count,
#    :last_request_at, :current_login_at, :last_login_at, 
#    :current_login_ip, :last_login_ip ]

#  acts_as_audited :protect => false
  acts_as_audited :only => [:login]

  def admin?
    role_id == 1
  end

  def calculator?
    role_id == 2
  end
end
