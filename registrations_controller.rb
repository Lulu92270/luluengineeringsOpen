class Api::V1::RegistrationsController < ApplicationController

  def create
    user = User.create!(
      email: params['user']['email'],
      password: params['user']['password'],
      password_confirmation: params['user']['password'],
    )

    if user
      UserMailer.registration_confirmation(user).deliver
      session[:user_id] = user.id
      render json: {
        status: :created,
        user: user
      }
    else
      render json: { status: 500 }
    end
  end

  def confirm_email
    user = User.find_by_confirm_token(params[:id])
    if user
      session[:user_id] = user.id
      user.email_activate
      redirect_to root_url
    else
      redirect_to root_url
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.full_name = ""
    @user.is_account_active = false
    @user.react_grid_layout_data = ""
    @user.pdf_date_refresh_limit = Date.today
    @user.premium_until = Date.today - 1.day
    @user.favourite_tool = ""
    @user.company_logo_url = ""
    del_projects = Api::V1::ProjectsController.new
    del_projects.destroy_all_projects(@user)
    
    @user.save!
    reset_session
    render json: @user
  end
  # METHOD TO SEND EMAIL CONFIRMATION AGAIN
  def send_again_confirm_email
    user = User.find_by(email: params[:_json])
    if user
      if user.email_confirmed
        render json: {
          alert: "If this email exists and you havn't already confirm your email, we have sent you an email confirmation."
        }
      else
        render json: {
          alert: "If this email exists and you havn't already confirm your email, we have sent you an email confirmation."
        }
        UserMailer.registration_confirmation(user).deliver
      end
    else
      #this sends regardless of whether there's an email in database for security reasons
      render json: {
        alert: "If this email exists and you havn't already confirm your email, we have sent you an email confirmation."
      }
    end
  end
end
