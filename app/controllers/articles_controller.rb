# coding: utf-8
class ArticlesController < ApplicationController
  before_filter :find_factor, :only => :new_article
  def new_article
    @article = Article.new
  end
  
  def save_article
    @article = Article.new params[:article]
    @article.factor_id = params[:factor_id]
    if not @article.save
      render :new
    else
      redirect_to :controller => 'directions', :action => 'show_articles', :id => params[:factor_id] 
    end
  end
  
  private
  
  def find_factor
    @factor = Factor.find params[:factor_id]  
  end

end