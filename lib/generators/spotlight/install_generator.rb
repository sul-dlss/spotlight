# frozen_string_literal: true

require 'rails/generators'

module Spotlight
  ##
  # spotlight:install generator
  class Install < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)
    class_option :solr_update_class, type: :string, default: 'Spotlight::SolrDocument::AtomicUpdates'
    class_option :mailer_default_url_host, type: :string, default: '' # e.g. localhost:3000

    # we're not (yet) using webpacker, so we need to re-add sprockets functionality
    def add_js
      return unless Rails.version.to_i == 6

      gem 'coffee-rails', '~> 4.2'
      gem 'uglifier', '>= 1.3.0'

      append_to_file 'app/assets/config/manifest.js', "\n//= link_directory ../javascripts .js\n"
      append_to_file 'app/assets/javascripts/application.js', "\n//= require_tree .\n"
      gsub_file 'app/views/layouts/application.html.erb', /pack/, 'include'
      inject_into_file 'config/environments/production.rb', after: '  # config.assets.css_compressor = :sass' do
        "\n  config.assets.js_compressor = :uglifier"
      end

      # but since webpacker exists in the gemfile, we still need to run the
      # install before rails will start
      run 'bundle exec rails webpacker:install'
    end

    def inject_spotlight_routes
      route "mount Spotlight::Engine, at: 'spotlight'"
      gsub_file 'config/routes.rb', /^\s*root.*/ do |match|
        '#  ' + match.strip + ' # replaced by spotlight root path'
      end
      route "root to: 'spotlight/exhibits#index'"
    end

    def friendly_id
      gem 'friendly_id'
      # we need to immediately run `bundle install` while pointing at github.
      Bundler.with_clean_env { run 'bundle install' }
      generate 'friendly_id'
    end

    def riiif
      gem 'riiif', git: 'https://github.com/curationexperts/riiif.git'
      Bundler.with_clean_env { run 'bundle install' }
      route "mount Riiif::Engine => '/images', as: 'riiif'"
      copy_file 'config/initializers/riiif.rb'
    end

    def paper_trail
      generate 'paper_trail:install'
    end

    def sitemaps
      gem 'sitemap_generator'

      Bundler.with_clean_env { run 'bundle install' }

      copy_file 'config/sitemap.rb', 'config/sitemap.rb'

      say <<-EOS.strip_heredoc, :red
       Added a default sitemap_generator configuration in config/sitemap.rb; please
       update the default host to match your environment
      EOS
    end

    def assets
      copy_file 'spotlight.scss', 'app/assets/stylesheets/spotlight.scss'
      copy_file 'spotlight.js', 'app/assets/javascripts/spotlight.js'
    end

    def add_roles_to_user
      inject_into_file 'app/models/user.rb', after: 'include Blacklight::User' do
        "\n  include Spotlight::User\n"
      end
    end

    def add_controller_mixin
      inject_into_file 'app/controllers/application_controller.rb', after: 'include Blacklight::Controller' do
        "\n  include Spotlight::Controller\n"
      end
    end

    def add_helper
      copy_file 'spotlight_helper.rb', 'app/helpers/spotlight_helper.rb'
      inject_into_file 'app/helpers/application_helper.rb', after: 'module ApplicationHelper' do
        "\n  include SpotlightHelper"
      end
    end

    def add_model_mixin
      if File.exist? 'app/models/solr_document.rb'
        inject_into_file 'app/models/solr_document.rb', after: 'include Blacklight::Solr::Document' do
          "\n  include Spotlight::SolrDocument\n"
        end
      else
        say 'Unable to find SolrDocument class; add `include Spotlight::SolrDocument` to the class manually'
      end
    end

    def add_solr_indexing_mixin
      if File.exist? 'app/models/solr_document.rb'
        inject_into_file 'app/models/solr_document.rb', after: "include Spotlight::SolrDocument\n" do
          "\n  include #{options[:solr_update_class]}\n"
        end
      else
        say "Unable to find SolrDocument class; add `include #{options[:solr_update_class]}` to the class manually"
      end
    end

    def add_search_builder_mixin
      if File.exist? 'app/models/search_builder.rb'
        inject_into_file 'app/models/search_builder.rb', after: "include Blacklight::Solr::SearchBuilderBehavior\n" do
          "\n  include Spotlight::SearchBuilder\n"
        end
      else
        say 'Unable to find SearchBuilder class; add `include Spotlight::SearchBuilder` to the class manually.'
      end
    end

    def add_example_catalog_controller
      copy_file 'catalog_controller.rb', 'app/controllers/catalog_controller.rb'
    end

    def add_osd_viewer
      gem 'blacklight-gallery', '~> 3.0'
      generate 'blacklight_gallery:install'
    end

    def add_oembed
      gem 'blacklight-oembed', '~> 1.0'
      Bundler.with_clean_env { run 'bundle install' }
      generate 'blacklight_oembed:install'
      copy_file 'config/initializers/oembed.rb'
    end

    def add_mailer_defaults
      if options[:mailer_default_url_host].present?
        say 'Injecting a placeholder config.action_mailer.default_url_options; be sure to update it for your environment', :yellow
        insert_into_file 'config/application.rb', after: "< Rails::Application\n" do
          <<-EOF
          config.action_mailer.default_url_options = { host: "#{options[:mailer_default_url_host]}", from: "noreply@example.com" }
          EOF
        end
      else
        say 'Please add a default configuration config.action_mailer.default_url_options for your environment', :red
      end
    end

    def generate_config
      directory 'config'
    end

    def add_solr_config_resources
      copy_file '.solr_wrapper.yml', '.solr_wrapper.yml'
      directory 'solr'
    end

    def generate_devise_invitable
      gem 'devise_invitable'
      generate 'devise_invitable:install'
      generate 'devise_invitable', 'User'
    end

    def add_translations
      copy_file 'config/initializers/translation.rb'
    end

    def configure_queue
      insert_into_file 'config/application.rb', after: "< Rails::Application\n" do
        <<-EOF
        config.active_job.queue_adapter = ENV["RAILS_QUEUE"].to_sym || :sidekiq
        EOF
      end
    end
    def configure_logging
      insert_into_file 'config/application.rb', after: "< Rails::Application\n" do
        <<-EOF
        # Logging
        if ENV["RAILS_LOG_TO_STDOUT"].present?
          config.log_level = :debug
          config.log_formatter = ::Logger::Formatter.new
          # log to stdout
          logger               = ActiveSupport::Logger.new(STDOUT)
          logger.formatter     = config.log_formatter
          config.logger        = ActiveSupport::TaggedLogging.new(logger)
          # Print deprecation notices to the Rails logger.
          config.active_support.deprecation = :log
          # Raise an error on page load if there are pending migrations.
          config.active_record.migration_error = :page_load
          # Highlight code that triggered database queries in logs.
          config.active_record.verbose_query_logs = true
        end
        EOF
      end
    end
  end
end
