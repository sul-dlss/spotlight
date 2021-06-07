# frozen_string_literal: true

require 'mail'
module Spotlight
  ##
  # Spotlight exhibit
  class Exhibit < ActiveRecord::Base
    class_attribute :themes_selector
    include Spotlight::ExhibitAnalytics
    include Spotlight::ExhibitDefaults
    include Spotlight::ExhibitDocuments
    include Spotlight::Translatables

    translates :title, :subtitle, :description

    has_paper_trail

    scope :published, -> { where(published: true) }
    scope :unpublished, -> { where(published: false) }
    scope :ordered_by_weight, -> { order('weight ASC') }

    paginates_per 48

    extend FriendlyId
    friendly_id :title, use: %i[slugged finders] do |config|
      config.reserved_words&.concat(%w[site])
    end

    validates :title, presence: true, if: -> { I18n.locale == I18n.default_locale }
    validates :slug, uniqueness: true
    validates :theme, inclusion: { in: Spotlight::Engine.config.exhibit_themes }, allow_blank: true

    after_validation :move_friendly_id_error_to_slug

    acts_as_tagger
    acts_as_taggable
    delegate :blacklight_config, to: :blacklight_configuration
    serialize :facets, Array

    # NOTE: friendly id associations need to be 'destroy'ed to reap the slug history
    has_many :about_pages, -> { for_default_locale }, extend: FriendlyId::FinderMethods
    has_many :attachments, dependent: :destroy
    has_many :contact_emails, dependent: :delete_all # These are the contacts who get "Contact us" emails
    has_many :contacts, dependent: :delete_all # These are the contacts who appear in the sidebar
    has_many :custom_fields, dependent: :delete_all do
      def as_strong_params
        multivalued_params, single_valued_params = writeable.partition(&:is_multiple?)
        single_valued_params.pluck(:slug, :field).flatten +
          [multivalued_params.each_with_object({}) do |f, h|
            h[f.slug] = []
            h[f.field] = []
          end]
      end
    end
    has_many :custom_search_fields, dependent: :delete_all

    has_many :feature_pages, -> { for_default_locale }, extend: FriendlyId::FinderMethods
    has_many :groups, dependent: :delete_all
    has_many :job_trackers, as: :on, dependent: :delete_all
    has_many :bulk_updates, dependent: :delete_all
    has_many :main_navigations, dependent: :delete_all
    has_many :resources
    has_many :roles, as: :resource, dependent: :delete_all
    has_many :searches, dependent: :destroy, extend: FriendlyId::FinderMethods
    has_many :solr_document_sidecars, dependent: :delete_all
    has_many :users, through: :roles, class_name: Spotlight::Engine.config.user_class

    has_many :pages, dependent: :destroy
    has_many :filters, dependent: :delete_all
    has_many :translations, class_name: 'I18n::Backend::ActiveRecord::Translation', dependent: :destroy, inverse_of: :exhibit
    has_many :languages, dependent: :destroy

    has_one :blacklight_configuration, class_name: 'Spotlight::BlacklightConfiguration', dependent: :delete
    has_one :home_page, -> { for_default_locale }

    belongs_to :site, optional: true
    belongs_to :masthead, dependent: :destroy, optional: true
    belongs_to :thumbnail, class_name: 'Spotlight::ExhibitThumbnail', dependent: :destroy, optional: true

    accepts_nested_attributes_for :about_pages, :attachments, :contacts, :custom_fields, :feature_pages, :groups, :languages,
                                  :main_navigations, :owned_taggings, :pages, :resources, :searches, :solr_document_sidecars, :translations
    accepts_nested_attributes_for :blacklight_configuration, :home_page, :filters, update_only: true
    accepts_nested_attributes_for :masthead, :thumbnail, update_only: true, reject_if: proc { |attr| attr['iiif_tilesource'].blank? }
    accepts_nested_attributes_for :contact_emails, reject_if: proc { |attr| attr['email'].blank? }
    accepts_nested_attributes_for :roles, allow_destroy: true, reject_if: proc { |attr| attr['user_key'].blank? && attr['id'].blank? }

    before_save :sanitize_description, if: :description_changed?

    def main_about_page
      @main_about_page ||= about_pages.for_locale.published.first
    end

    def browse_categories?
      searches.published.any?
    end

    def themes
      @themes ||= begin
        return Spotlight::Engine.config.exhibit_themes unless self.class.themes_selector

        self.class.themes_selector.call(self)
      end
    end

    def to_s
      title
    end

    def import(hash)
      ActiveRecord::Base.transaction do
        Spotlight::ExhibitImportExportService.new(self).from_hash!(hash)
        save
      end
    end

    def solr_data
      filters.each_with_object({}) do |filter, hash|
        hash.merge! filter.to_hash
      end
    end

    def reindex_later(current_user = nil)
      Spotlight::ReindexExhibitJob.perform_later(self, user: current_user)
    end

    def uploaded_resource_fields
      Spotlight::Engine.config.upload_fields
    end

    def searchable?
      blacklight_config.search_fields.any? { |_k, v| v.enabled && v.include_in_simple_select != false }
    end

    def requested_by
      roles.first&.user
    end

    def reindex_progress
      @reindex_progress ||= BackgroundJobProgress.new(self, job_class: Spotlight::ReindexExhibitJob)
    end

    def available_locales
      @available_locales ||= languages.pluck(:locale)
    end

    protected

    def sanitize_description
      self.description = ::Rails::Html::FullSanitizer.new.sanitize(description)
    end

    private

    def move_friendly_id_error_to_slug
      errors.add :slug, *errors.delete(:friendly_id) if errors[:friendly_id].present?
    end
  end
end
