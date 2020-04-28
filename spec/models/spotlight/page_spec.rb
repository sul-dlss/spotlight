# frozen_string_literal: true

describe Spotlight::Page, type: :model do
  let(:exhibit) { FactoryBot.create(:exhibit) }
  let!(:parent_page) { Spotlight::FeaturePage.create! exhibit: exhibit, published: true }
  let!(:child_page) { Spotlight::FeaturePage.create! exhibit: exhibit, published: false, parent_page: parent_page }

  describe '.at_top_level' do
    it 'scopes results to only top level pages' do
      expect(described_class.at_top_level).not_to include child_page
    end
  end

  describe '.published' do
    it 'scopes results to only published pages' do
      expect(described_class.at_top_level).not_to include child_page
    end
  end

  it 'is expected to be versioned' do
    expect(subject).to be_versioned
  end

  describe '#top_level_page?' do
    it 'checks if the page is a top-level page' do
      expect(parent_page).to be_a_top_level_page
      expect(child_page).not_to be_a_top_level_page
    end
  end

  describe '#top_level_page_or_self' do
    it 'fetches the top level page' do
      expect(child_page.top_level_page_or_self).to be parent_page
    end

    it 'is the same object if the page is a top level page' do
      expect(parent_page.top_level_page_or_self).to be parent_page
    end
  end

  describe '.display_sidebar' do
    it 'is set to true by default' do
      expect(parent_page).to be_display_sidebar
    end
  end

  describe 'should_display_title?' do
    let(:page) { FactoryBot.create(:feature_page) }

    it 'returns if the title is present or not' do
      expect(page.title).not_to be_blank
      expect(page).to be_should_display_title
      page.title = ''
      expect(page).not_to be_should_display_title
    end
  end

  describe '#content=' do
    let(:page) { FactoryBot.create(:feature_page) }

    it 'works with a serialized JSON array' do
      page.content = [].to_json
      expect(page.content).to be_a_kind_of SirTrevorRails::BlockArray
    end

    it 'works with an array' do
      page.content = []
      expect(page.content).to be_a_kind_of SirTrevorRails::BlockArray
    end

    context 'with an alternate page content type' do
      let(:page) { FactoryBot.create(:feature_page, content_type: 'Static') }
      let(:fake_class) do
        Class.new do
          def self.parse(*_args)
            'xyz'
          end
        end
      end

      before do
        # needed so we don't accidentally stub Spotlight::PageContent below
        require 'spotlight/page_content'
        stub_const('Spotlight::PageContent::Static', fake_class)
      end

      it 'works' do
        page.content = [].to_json
        expect(page.content).to eq 'xyz'
      end
    end
  end

  describe '#content?' do
    let(:page) { FactoryBot.create(:feature_page) }

    it 'does not have content when the page is empty' do
      page.content = []
      expect(page).not_to have_content
    end

    it 'has content when the page has a widget' do
      page.content = [{ type: 'rule' }]
      expect(page).to have_content
    end
  end

  describe '#content_type' do
    let(:page) { FactoryBot.create(:feature_page) }

    it 'can be set as an attribute' do
      page.content_type = 'Xyz'
      expect(page.content_type).to eq 'Xyz'
    end

    it 'defauts to SirTrevor' do
      expect(page.content_type).to eq 'SirTrevor'
    end
  end

  describe '#slug' do
    let(:page) { FactoryBot.create(:feature_page) }

    it 'gets a default slug' do
      expect(page.slug).not_to be_blank
    end

    it 'is updated when the title changes' do
      page.update(title: 'abc')
      expect(page.slug).to eq 'abc'
    end

    context 'with a custom slug' do
      let(:page) { FactoryBot.create(:feature_page, slug: 'xyz') }

      it 'gets a default slug' do
        expect(page.slug).to eq 'xyz'
      end
    end

    context 'different types of pages with the same slug' do
      it 'are allowed' do
        FactoryBot.create(:feature_page, exhibit: exhibit, title: 'MyCustomPage')

        expect do
          FactoryBot.create(:about_page, exhibit: exhibit, title: 'MyCustomPage')
        end.not_to raise_error
      end
    end
  end

  describe 'thumbnail_image_url' do
    subject(:page) { FactoryBot.create(:feature_page, exhibit: exhibit) }

    let(:thumbnail) { FactoryBot.create(:featured_image) }

    it 'is nil when there is no thumbnail' do
      expect(page.thumbnail_image_url).to be_nil
    end

    it "is returns the thumbnail's IIIF url" do
      page.thumbnail = thumbnail
      expect(page.thumbnail_image_url).to eq thumbnail.iiif_url
    end
  end

  describe 'updated_after?' do
    let!(:old_page) { FactoryBot.create(:feature_page, updated_at: 10.seconds.ago) }
    let!(:new_page) { FactoryBot.create(:feature_page) }

    it 'compares the updated_at of the two objects' do
      expect(new_page).to be_updated_after(old_page)
    end
  end

  describe 'translated_pages' do
    subject!(:page) { FactoryBot.create(:feature_page, exhibit: exhibit) }

    let!(:page_es) { FactoryBot.create(:feature_page, exhibit: exhibit, locale: 'es', default_locale_page: page) }

    it 'is a relation of the other pages that indicate they belong to this page' do
      expect(page.translated_pages.length).to eq 1
      expect(page.translated_pages.first).to eq page_es
    end
  end

  describe 'clone_for_locale' do
    subject!(:cloned_page) { page.clone_for_locale('es') }

    let(:page) { FactoryBot.create(:feature_page, exhibit: exhibit, published: true) }

    it 'creates a new page' do
      expect do
        cloned_page.save
      end.to change(described_class, :count).by(1)
    end

    it 'has the given locale' do
      expect(cloned_page.locale).to eq 'es'
    end

    it 'sets the default_locale_page to self' do
      expect(cloned_page.default_locale_page).to eq page
    end

    it 'does not copy the published attribute to the cloned page' do
      expect(page).to be_published
      expect(cloned_page).not_to be_published
    end

    context 'when cloning a child page' do
      let(:parent_page) { FactoryBot.create(:feature_page, exhibit: exhibit) }
      let(:parent_cloned_page) { parent_page.clone_for_locale('es') }

      before do
        parent_cloned_page.save
        page.update(parent_page_id: parent_page.id)
      end

      it 'associates the page with the translated version (if present)' do
        expect(page.clone_for_locale('es').parent_page.id).to eq parent_cloned_page.id
      end
    end

    context 'when cloning a page that has been deleted with a FriendlyId UUID added' do
      let(:feature_page_static_title) { FactoryBot.create(:feature_page_static_title, exhibit: exhibit) }
      let(:feature_page_static_title_two) { FactoryBot.create(:feature_page_static_title, exhibit: exhibit) }

      it 'translated page has the same UUID' do
        expect(feature_page_static_title.slug).to eq 'featurepage'
        expect(feature_page_static_title_two.slug).not_to eq feature_page_static_title.slug
        expect(feature_page_static_title_two.clone_for_locale('es').slug).to eq feature_page_static_title_two.slug
      end
    end

    context 'when cloning a parent page whose children pages have already been cloned' do
      let(:parent_page_es) { parent_page.clone_for_locale('es') }
      let(:child_page_es) { child_page.clone_for_locale('es') }

      before { child_page_es.save }

      it 'updates the translated child pages with the correct parent association' do
        expect(child_page_es.parent_page).to eq parent_page
        parent_page_es.save
        expect(child_page_es.reload.parent_page).to eq parent_page_es
      end
    end
  end

  describe 'syncing data between translated pages' do
    let!(:parent_page_es) do
      FactoryBot.create(
        :feature_page,
        exhibit: exhibit,
        locale: 'es',
        default_locale_page: parent_page
      )
    end
    let!(:child_page_es) do
      FactoryBot.create(
        :feature_page,
        exhibit: exhibit,
        locale: 'es',
        default_locale_page: child_page,
        parent_page: parent_page_es
      )
    end
    let!(:another_translated_page_es) do
      FactoryBot.create(
        :feature_page,
        exhibit: exhibit,
        locale: 'es',
        default_locale_page: another_translated_page
      )
    end
    let!(:another_page) { Spotlight::FeaturePage.create exhibit: exhibit, published: true }
    let!(:another_translated_page) { Spotlight::FeaturePage.create exhibit: exhibit, published: true }

    it 'updates the translated pages weight' do
      expect(parent_page_es.weight).not_to be 5
      parent_page.update(weight: 5)
      expect(parent_page_es.reload.weight).to be 5
    end

    it 'sets the parent page id to the equivalent translated parent page' do
      child_page.update(parent_page: another_translated_page)
      expect(child_page_es.reload.parent_page).to eq another_translated_page_es
    end

    it 'updates the parent page when the default locale page becomes a top-level page' do
      expect(child_page_es.parent_page).to eq parent_page_es
      child_page.update(parent_page: nil)
      expect(child_page_es.reload.parent_page).to be_nil
    end

    it 'removes the parent page id when the child page is set to an as-yet-untranslated parent page' do
      child_page.update(parent_page: another_page)
      expect(child_page_es.reload.parent_page).to be_nil
    end

    it 'updates the attributes separately' do
      expect(child_page_es.parent_page).to eq parent_page_es
      child_page.update(weight: 5)
      expect(child_page_es.reload.weight).to eq 5
      expect(child_page_es.reload.parent_page).to eq parent_page_es
    end
  end
end
