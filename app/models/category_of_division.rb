class CategoryOfDivision < Commerce
  has_many :factors
  set_table_name "FIN.DIVISION_BRANCH"
end