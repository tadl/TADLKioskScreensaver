# config/initializers/omniauth.rb

require 'omniauth'
require 'omniauth-google-oauth2'

if Rails.env.production?
  OmniAuth.config.full_host = 'https://kiosks.tadl.org'
end

# Re-enable GET (and silence the warning)
OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning    = true

Rails.application.config.middleware.use OmniAuth::Builder do
  google_id     = ENV['GOOGLE_CLIENT_ID']
  google_secret = ENV['GOOGLE_CLIENT_SECRET']

  if google_id.present? && google_secret.present?
    provider :google_oauth2,
      google_id,
      google_secret,
      {
        scope:  'userinfo.email,userinfo.profile',
        hd:     'tadl.org',
        prompt: 'select_account',
      }
  else
    Rails.logger.warn "[OmniAuth] Skipping Google provider: GOOGLE_CLIENT_ID/SECRET not set"
  end
end

