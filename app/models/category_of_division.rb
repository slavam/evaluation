class CategoryOfDivision < Commerce
  has_many :factors
  self.table_name = "FIN.DIVISION_BRANCH"
end