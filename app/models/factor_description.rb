class FactorDescription < ActiveRecord::Base
  has_many :factors
  belongs_to :unit
end