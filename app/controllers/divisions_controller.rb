# coding: utf-8
class DivisionsController < ApplicationController
  def index
    @divisions = Division.order(:id)
  end

end