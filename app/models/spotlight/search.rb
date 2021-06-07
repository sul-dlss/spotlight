# frozen_string_literal: true

module Spotlight
  ##
  # Exhibit saved searches
  class Search < ActiveRecord::Base
    include Spotlight::Translatables
    include Spotlight::SearchHelper

    extend FriendlyId
    friendly_id :title, use: %i[slugged scoped finders history], scope: :exhibit

    self.table_name = 'spotlight_searches'
    belongs_to :exhibit
    has_many :group_memberships, class_name: 'Spotlight::GroupMember', as: :member, dependent: :delete_all
    has_many :groups, through: :group_memberships
    accepts_nested_attributes_for :group_memberships
    accepts_nested_attributes_for :groups
    serialize :query_params, Hash
    default_scope { order('weight ASC') }
    scope :published, -> { where(published: true) }
    scope :unpublished, -> { where(published: [nil, false]) }
    validates :title, presence: true

    translates :title, :subtitle, :long_description

    has_paper_trail

    belongs_to :masthead, dependent: :destroy, optional: true
    belongs_to :thumbnail, class_name: 'Spotlight::FeaturedImage', dependent: :destroy, optional: true
    accepts_nested_attributes_for :thumbnail, update_only: true, reject_if: proc { |attr| attr['iiif_tilesource'].blank? }
    accepts_nested_attributes_for :masthead, update_only: true, reject_if: proc { |attr| attr['iiif_tilesource'].blank? }

    def full_title
      [title, subtitle.presence].compact.join(' · ')
    end

    def thumbnail_image_url
      return unless thumbnail&.iiif_url

      thumbnail.iiif_url
    end

    def documents(&block)
      start = 0
      response = repository.search(search_params.start(start))

      return to_enum(:documents) { response['response']['numFound'] } unless block_given?

      while response.documents.present?
        response.documents.each(&block)
        start += response.documents.length
        response = repository.search(search_params.start(start))
      end
    end

    def count
      @count ||= Rails.cache.fetch([exhibit, self, 'count']) do
        documents.size
      end
    end

    delegate :blacklight_config, to: :exhibit

    def display_masthead?
      masthead&.display?
    end

    def search_params
      search_service.search_builder.with(query_params.with_indifferent_access).merge(facet: false)
    end

    def merge_params_for_search(params, blacklight_config)
      base_query = Blacklight::SearchState.new(query_params, blacklight_config)
      user_query = Blacklight::SearchState.new(params, blacklight_config).to_h
      base_query.params_for_search(user_query).merge(user_query.slice(:page))
    end

    private

    def repository
      @repository ||= Blacklight::Solr::Repository.new(blacklight_config)
    end

    def should_generate_new_friendly_id?
      return false if new_record? && slug.present?

      super || (title_changed? && persisted?)
    end

    alias current_exhibit exhibit
  end
end
