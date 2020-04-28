# frozen_string_literal: true

module Spotlight
  ##
  # Feature pages
  class FeaturePage < Spotlight::Page
    extend FriendlyId
    friendly_id :title, use: %i[slugged scoped finders history], scope: %i[exhibit locale type]

    has_many :child_pages, class_name: 'Spotlight::FeaturePage', inverse_of: :parent_page, foreign_key: 'parent_page_id'
    belongs_to :parent_page, class_name: 'Spotlight::FeaturePage', optional: true

    accepts_nested_attributes_for :child_pages

    belongs_to :thumbnail, class_name: 'Spotlight::FeaturedImage', dependent: :destroy, optional: true

    before_validation unless: :top_level_page? do
      self.exhibit = top_level_page_or_self.exhibit
    end

    def display_sidebar?
      child_pages.published.present? || display_sidebar
    end
  end
end
