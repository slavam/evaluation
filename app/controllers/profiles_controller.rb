class ProfilesController < ApplicationController
  before_filter :require_user

  def show
  end

  def edit
  end

  def update
    @current_user.email = params[:user][:email]
    if not @current_user.save
      render :action => :edit
    else
      notice_updated
      redirect_to profile_path
    end
  end
end

