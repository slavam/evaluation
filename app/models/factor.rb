class Factor < ActiveRecord::Base
  belongs_to :factor_description
  belongs_to :block
  has_many :factor_weights
  has_many :articles  
  has_many :performances
  has_many :params
end