# frozen_string_literal: true

require 'signet/oauth_2/client'
require 'legato'

module Spotlight
  module Analytics
    ##
    # Google Analytics data provider for the Exhibit dashboard
    class Ga
      extend Legato::Model

      def enabled?
        user && site
      end

      delegate :metrics, to: :model

      def exhibit_data(exhibit, options)
        model.context(exhibit).results(site, Spotlight::Engine.config.ga_analytics_options.merge(options)).to_a.first || exhibit_data_unavailable
      end

      def page_data(exhibit, options)
        options[:sort] ||= '-pageviews'
        query = model.context(exhibit).results(site, Spotlight::Engine.config.ga_page_analytics_options.merge(options))
        query.dimensions << :page_path
        query.dimensions << :page_title

        query.to_a
      end

      def user(scope = 'https://www.googleapis.com/auth/analytics.readonly')
        @user ||= begin
          Legato::User.new(oauth_token(scope))
        rescue StandardError => e
          Rails.logger.info(e)
          nil
        end
      end

      def site
        @site ||= user.accounts.first.profiles.find { |x| x.web_property_id == Spotlight::Engine.config.ga_web_property_id }
      end

      private

      def model
        Spotlight::Analytics::GaModel
      end

      def exhibit_data_unavailable
        OpenStruct.new(pageviews: 'n/a', users: 'n/a', sessions: 'n/a')
      end

      def oauth_token(scope)
        require 'oauth2'

        access_token = auth_client(scope).fetch_access_token!
        OAuth2::AccessToken.new(oauth_client, access_token['access_token'], expires_in: access_token['expires_in'])
      end

      def oauth_client
        OAuth2::Client.new('', '', authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                                   token_url: 'https://accounts.google.com/o/oauth2/token')
      end

      def signing_key
        @signing_key ||= OpenSSL::PKCS12.new(File.read(Spotlight::Engine.config.ga_pkcs12_key_path), 'notasecret').key
      end

      def auth_client(scope)
        Signet::OAuth2::Client.new token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
                                   audience: 'https://accounts.google.com/o/oauth2/token',
                                   scope: scope,
                                   issuer: Spotlight::Engine.config.ga_email,
                                   signing_key: signing_key,
                                   sub: Spotlight::Engine.config.ga_email
      end
    end
  end
end
