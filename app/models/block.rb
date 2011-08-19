class Block < ActiveRecord::Base
  belongs_to :direction
  belongs_to :block_description
  has_many :block_weights
  has_many :factors
  has_many :performances
end