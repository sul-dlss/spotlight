# frozen_string_literal: true

require 'migration/add_page_type_to_friendly_id_scope'

RSpec.describe Migration::AddPageTypeToFriendlyIdScope do
  subject { described_class }

  describe '#run' do
    let(:exhibit) { FactoryBot.create(:exhibit) }
    let(:page) { FactoryBot.create(:feature_page, exhibit: exhibit) }
    let(:slug) { FriendlyId::Slug.find(page.id) }

    before do
      # Remove type from the scope
      slug.scope = slug.scope.sub(',type:Spotlight::FeaturePage', '')
      slug.save
      slug.reload
    end

    it 'sets the scope to the default locale' do
      expect(slug.scope).not_to include(',type:')
      subject.run
      slug.reload
      expect(slug.scope).to end_with(',type:Spotlight::FeaturePage')
    end

    it 'sorts the scope parts per friendly_id expectation' do
      # reverse the slug
      slug.scope = slug.scope.split(',').reverse.join(',')
      expect(slug.scope).to match(/locale:.*,exhibit_id:.*/)
      slug.save
      subject.run
      slug.reload
      expect(slug.scope).to match(/exhibit_id:.*,locale:.*,type:.*/)
    end
  end
end
