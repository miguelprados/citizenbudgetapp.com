class PagesController < ApplicationController
  skip_before_filter :set_locale
  caches_action :channel, :not_found

  def oauth2callback
    if params[:state]
      questionnaire = Questionnaire.find(params[:state])
      if params[:code]
        if questionnaire.google_api_authorization.configured?
          begin
            questionnaire.google_api_authorization.redeem_authorization_code! params[:code]
          rescue # GoogleAPIAuthorization::CodeExchangeError
            flash[:error] = t('google_api.code_exchange_error')
          end
        else
          flash[:error] = t('google_api.not_configured')
        end
      elsif params[:error]
        flash[:error] = t('google_api.authentication_error')
      else
        flash[:error] = t('google_api.no_authorization_code')
      end
      redirect_to [:admin, questionnaire]
    else
      flash[:error] = t('google_api.no_state')
      redirect_to admin_root_path
    end
  end

  def channel
    expires_in 1.hour, public: true
    render layout: false
  end

  def not_found
    expires_in 1.hour, public: true
    render file: "#{Rails.root}/public/404.html", status: 404, layout: false
  end
end
