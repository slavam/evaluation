class Factor < ActiveRecord::Base
  belongs_to :factor_description
  belongs_to :block
  belongs_to :category_of_division, :class_name => 'CategoryOfDivision', :foreign_key => 'div_category_id'
  has_many :factor_weights
  has_many :articles  
  has_many :performances
  has_many :params
end