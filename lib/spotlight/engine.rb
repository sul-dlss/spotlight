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

module Spotlight
  ##
  # Spotlight::Engine
  class Engine < ::Rails::Engine
    isolate_namespace Spotlight
    # Breadcrumbs on rails must be required outside of an initializer or it doesn't get loaded.
    require 'breadcrumbs_on_rails'
    require 'carrierwave'
    require 'carrierwave/crop'
    require 'social-share-button'
    require 'lodash-rails'
    require 'github/markup'
    require 'sir_trevor_rails'
    require 'openseadragon'

    config.autoload_paths += %W(
      #{config.root}/app/builders
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

    initializer 'spotlight.factories', after: 'factory_girl.set_factory_paths' do
      FactoryGirl.definition_file_paths << File.expand_path('../../../spec/factories', __FILE__) if defined?(FactoryGirl)
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

    Spotlight::Engine.config.user_class = '::User'

    Spotlight::Engine.config.catalog_controller_class = '::CatalogController'
    Spotlight::Engine.config.default_blacklight_config = nil

    Spotlight::Engine.config.exhibit_main_navigation = [:curated_features, :browse, :about]

    Spotlight::Engine.config.resource_providers = []
    Spotlight::Engine.config.new_resource_partials = [] # e.g. "spotlight/resources/bookmarklet"
    Spotlight::Engine.config.uploaded_resource_partials = ['spotlight/resources/upload/single_item_form', 'spotlight/resources/upload/multi_item_form']
    Spotlight::Engine.config.solr_batch_size = 20

    # Filter resources by exhibit by default
    Spotlight::Engine.config.filter_resources_by_exhibit = true
    # The allowed file extensions for uploading non-repository items.
    Spotlight::Engine.config.allowed_upload_extensions = %w(jpg jpeg png)

    # Suffixes for exhibit-specific solr fields
    Spotlight::Engine.config.solr_fields = OpenStruct.new
    Spotlight::Engine.config.solr_fields.prefix = ''.freeze
    Spotlight::Engine.config.solr_fields.boolean_suffix = '_bsi'.freeze
    Spotlight::Engine.config.solr_fields.string_suffix = '_ssim'.freeze
    Spotlight::Engine.config.solr_fields.text_suffix = '_tesim'.freeze

    Spotlight::Engine.config.resource_global_id_field = :"#{config.solr_fields.prefix}spotlight_resource_id#{config.solr_fields.string_suffix}"

    # The solr field that original (largest) images will be stored.
    Spotlight::Engine.config.full_image_field = :full_image_url_ssm
    Spotlight::Engine.config.thumbnail_field = :thumbnail_url_ssm
    Spotlight::Engine.config.square_image_field = :thumbnail_square_url_ssm

    # Defaults to the blacklight_config.index.title_field:
    Spotlight::Engine.config.upload_title_field = nil # OpenStruct.new(...)

    Spotlight::Engine.config.upload_fields = [
      OpenStruct.new(field_name: :spotlight_upload_description_tesim, label: 'Description', form_field_type: :text_area),
      OpenStruct.new(field_name: :spotlight_upload_attribution_tesim, label: 'Attribution'),
      OpenStruct.new(field_name: :spotlight_upload_date_tesim, label: 'Date')
    ]

    # Configure the CarrierWave file storage mechanism
    Spotlight::Engine.config.uploader_storage = :file
    Spotlight::Engine.config.featured_image_thumb_size = [400, 300]
    Spotlight::Engine.config.featured_image_square_size = [400, 400]

    initializer 'spotlight-assets.initialize' do
      Rails.application.config.assets.precompile += %w( Jcrop.gif )
    end

    # To present curators with analytics reports on the exhibit dashboard, you need to configure
    # an Analytics provider. Google Analytics support is provided out-of-the-box.
    Spotlight::Engine.config.analytics_provider = nil

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
    Spotlight::Engine.config.ga_pkcs12_key_path = nil
    Spotlight::Engine.config.ga_web_property_id = nil
    Spotlight::Engine.config.ga_email = nil
    Spotlight::Engine.config.ga_analytics_options = {}
    Spotlight::Engine.config.ga_page_analytics_options = Spotlight::Engine.config.ga_analytics_options.merge(limit: 5)

    Blacklight::Engine.config.inject_blacklight_helpers = false

    # Query parameters for autocomplete requests
    Spotlight::Engine.config.autocomplete_search_field = 'autocomplete'
    Spotlight::Engine.config.default_autocomplete_params = { qf: 'id^1000 full_title_tesim^100 id_ng full_title_ng',
                                                             facet: false,
                                                             'facet.field' => [] }

    Spotlight::Engine.config.default_browse_index_view_type = :gallery

    initializer 'blacklight.configuration' do
      # Field containing the last modified date for a Solr document
      Blacklight::Configuration.default_values[:index].timestamp_field ||= 'timestamp'

      # Default configuration for the browse view
      Blacklight::Configuration.default_values[:browse] ||= Blacklight::OpenStructWithHashAccess.new(document_actions: [])
    end

    # make blacklight configuration play nice with bootstrap_form
    Blacklight::OpenStructWithHashAccess.send(:extend, ActiveModel::Translation)

    # Configuration defaults
    Spotlight::Engine.config.index_writer = Spotlight::Indexer::LocalWriter
  end
end
