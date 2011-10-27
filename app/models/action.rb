class Action < ActiveRecord::Base
  has_many :articles
  has_many :values
end