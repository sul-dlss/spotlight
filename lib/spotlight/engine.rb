# frozen_string_literal: true

# Load blacklight which will give spotlight views a higher preference than those in blacklight

# devise must be required to first to ensure we can override devise and invitable views in spotlight correctly
require 'devise'
require 'devise_invitable'

require 'blacklight'
require 'blacklight/oembed'
require 'autoprefixer-rails'
require 'friendly_id'
require 'tophat'
require 'paper_trail'
require 'clipboard/rails'
require 'leaflet-rails'
require 'i18n/active_record'
require 'spotlight/upload_field_config'
require 'riiif'

module Spotlight
  ##
  # Spotlight::Engine
  # rubocop:disable ClassLength
  class Engine < ::Rails::Engine
    isolate_namespace Spotlight
    # Breadcrumbs on rails must be required outside of an initializer or it doesn't get loaded.
    require 'breadcrumbs_on_rails/breadcrumbs'
    require 'breadcrumbs_on_rails/action_controller'

    initializer 'breadcrumbs_on_rails.initialize' do
      ActiveSupport.on_load(:action_controller) do
        include BreadcrumbsOnRails::ActionController
      end
    end

    require 'carrierwave'
    require 'underscore-rails'
    require 'github/markup'
    require 'sir_trevor_rails'
    require 'openseadragon'
    require 'sprockets/es6'
    require 'almond-rails'

    config.assets.precompile += %w(spotlight/fallback/*.png)

    config.autoload_paths += %W(
      #{config.root}/app/builders
      #{config.root}/app/controllers/concerns
      #{config.root}/app/models/concerns
    )

    initializer 'spotlight.initialize' do
      require 'cancan'
      require 'bootstrap_form'
      require 'acts-as-taggable-on'
      require 'oembed'

      Mime::Type.register 'application/solr+json', :solr_json
    end

    initializer 'oembed.initialize' do
      OEmbed::Providers.register_all
    end

    initializer 'spotlight.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../../spec/factories', __FILE__) if defined?(FactoryBot)
    end

    initializer 'spotlight.assets.precompile' do |app|
      app.config.assets.precompile += %w(spotlight/default_thumbnail.jpg spotlight/default_browse_thumbnail.jpg)

      Sprockets::ES6.configuration = { 'modules' => 'amd', 'moduleIds' => true }
      # When we upgrade to Sprockets 4, we can ditch sprockets-es6 and config AMD
      # in this way:
      # https://github.com/rails/sprockets/issues/73#issuecomment-139113466
    end

    def self.user_class
      Spotlight::Engine.config.user_class.constantize
    end

    def self.catalog_controller
      Spotlight::Engine.config.catalog_controller_class.constantize
    end

    def self.blacklight_config
      Spotlight::Engine.config.default_blacklight_config || catalog_controller.blacklight_config
    end

    config.user_class = '::User'

    config.catalog_controller_class = '::CatalogController'
    config.default_blacklight_config = nil

    config.exhibit_main_navigation = [:curated_features, :browse, :about]

    config.resource_partials = [
      'spotlight/resources/external_resources_form',
      'spotlight/resources/upload/form',
      'spotlight/resources/csv_upload/form',
      'spotlight/resources/json_upload/form',
      'spotlight/resources/iiif/form'
    ]
    config.external_resources_partials = []
    config.solr_batch_size = 20

    Spotlight::Engine.config.reindex_progress_window = 10

    # Filter resources by exhibit by default
    config.filter_resources_by_exhibit = true

    # Should Spotlight write to solr? If set to false, Spotlight will not initiate indexing.
    config.writable_index = true

    # The allowed file extensions for uploading non-repository items.
    config.allowed_upload_extensions = %w(jpg jpeg png)

    # Suffixes for exhibit-specific solr fields
    config.solr_fields = OpenStruct.new
    config.solr_fields.prefix = ''
    config.solr_fields.boolean_suffix = '_bsi'
    config.solr_fields.string_suffix = '_ssim'
    config.solr_fields.text_suffix = '_tesim'

    config.resource_global_id_field = :"#{config.solr_fields.prefix}spotlight_resource_id#{config.solr_fields.string_suffix}"

    # Set to nil if you don't want to pull thumbnails from the index
    config.full_image_field = :full_image_url_ssm
    config.thumbnail_field = :thumbnail_url_ssm

    # Defaults to the blacklight_config.index.title_field:
    config.upload_title_field = nil # UploadFieldConfig.new(...)
    config.upload_description_field = :spotlight_upload_description_tesim

    config.upload_fields = [
      UploadFieldConfig.new(
        field_name: config.upload_description_field,
        label: -> { I18n.t(:"spotlight.search.fields.#{config.upload_description_field}") },
        form_field_type: :text_area
      ),
      UploadFieldConfig.new(
        field_name: :spotlight_upload_attribution_tesim,
        label: -> { I18n.t(:'spotlight.search.fields.spotlight_upload_attribution_tesim') }
      ),
      UploadFieldConfig.new(
        field_name: :spotlight_upload_date_tesim,
        label: -> { I18n.t(:'spotlight.search.fields.spotlight_upload_date_tesim') }
      )
    ]

    config.iiif_manifest_field = :iiif_manifest_url_ssi
    config.iiif_metadata_class = -> { Spotlight::Resources::IiifManifest::Metadata }
    config.iiif_collection_id_field = :collection_id_ssim
    config.iiif_title_fields = nil
    config.default_json_ld_language = 'en'

    config.masthead_initial_crop_selection = [1200, 120]
    config.thumbnail_initial_crop_selection = [120, 120]

    # Configure the CarrierWave file storage mechanism
    config.uploader_storage = :file
    config.featured_image_thumb_size = [400, 300]
    config.featured_image_square_size = [400, 400]
    config.contact_square_size = [70, 70]

    # Additional page configurations to be made available to page editing widgets
    # See Spotlight::PageConfigurations
    config.page_configurations = {}

    # To present curators with analytics reports on the exhibit dashboard, you need to configure
    # an Analytics provider. Google Analytics support is provided out-of-the-box.
    config.analytics_provider = nil

    initializer 'analytics.initialize' do
      Spotlight::Engine.config.analytics_provider = Spotlight::Analytics::Ga
    end

    # If you use Google Analytics, you need to wire your site to report to a Google Analytics property.
    # Adding Google Analytics to your site is left as an excersize for the implementor (you could
    # consider overriding the layout to inject GA code..)
    #
    # After getting your site to report to Google Analytics, you need to:
    # a) register an OAuth service account with access to your analytics property:
    #     (https://github.com/tpitale/legato/wiki/OAuth2-and-Google#registering-for-api-access)
    # b) download the pkcs12 key and make it accessible to your application
    # c) in e.g. an initializer, set these configuration values as appropriate
    #    to your OAuth2 service account and analytics property:
    config.ga_pkcs12_key_path = nil
    config.ga_web_property_id = nil
    config.ga_email = nil
    config.ga_analytics_options = {}
    config.ga_page_analytics_options = config.ga_analytics_options.merge(limit: 5)
    config.ga_anonymize_ip = false # false for backwards compatibility

    Blacklight::Engine.config.inject_blacklight_helpers = false

    config.i18n_locales = {
      de: 'Deutsch',
      en: 'English',
      es: 'Español',
      fr: 'Français',
      it: 'Italiano',
      hu: 'Magyar',
      nl: 'Nederlands',
      'pt-BR': 'Português brasileiro',
      sq: 'Shqip',
      zh: '中文'
    }

    # Whitelisting the available_locales is necessary here, as any dependency we
    # add could add an available locale which could break things if unexpected.
    config.i18n.available_locales = config.i18n_locales.keys

    # Query parameters for autocomplete requests
    config.autocomplete_search_field = 'autocomplete'
    config.default_autocomplete_params = { qf: 'id^1000 full_title_tesim^100 id_ng full_title_ng',
                                           facet: false,
                                           'facet.field' => [] }

    config.default_browse_index_view_type = :gallery

    # default email address to send "Report a Problem" feedback to (in addition to any exhibit-specific contacts)
    config.default_contact_email = nil

    config.spambot_honeypot_email_field = :email_address

    initializer 'blacklight.configuration' do
      # Field containing the last modified date for a Solr document
      Blacklight::Configuration.default_values[:index].timestamp_field ||= 'timestamp'

      # Default configuration for the browse view
      Blacklight::Configuration.default_values[:browse] ||= Blacklight::OpenStructWithHashAccess.new(document_actions: [])
    end

    # make blacklight configuration play nice with bootstrap_form
    Blacklight::OpenStructWithHashAccess.send(:extend, ActiveModel::Translation)

    config.exhibit_themes = ['default']

    config.sir_trevor_widgets = %w(
      Heading Text Wysiwyg List Quote Iframe Video Oembed Rule UploadedItems Browse LinkToSearch
      FeaturedPages SolrDocuments SolrDocumentsCarousel SolrDocumentsEmbed
      SolrDocumentsFeatures SolrDocumentsGrid SearchResults
    )
  end
end
