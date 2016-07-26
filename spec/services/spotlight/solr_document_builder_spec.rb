describe Spotlight::SolrDocumentBuilder do
  let(:exhibit) { FactoryGirl.create(:exhibit) }
  let(:doc_builder) { described_class.new(resource) }
  let(:resource) { Spotlight::Resource.new }

  describe '#to_solr' do
    subject { doc_builder.send(:to_solr) }

    before do
      allow(resource).to receive(:exhibit).and_return(exhibit)
      allow(resource).to receive_messages(type: 'Spotlight::Resource::Something', id: 15, persisted?: true)
    end
    it 'includes a reference to the resource' do
      expect(subject).to include spotlight_resource_id_ssim: resource.to_global_id.to_s
    end
  end

  describe '#documents_to_index' do
    context 'when the document belongs to more than one exhibit' do
      let(:doc) { SolrDocument.new(id: 'abc123') }
      let(:resource) { FactoryGirl.create(:resource) }
      let(:resource_alt) { FactoryGirl.create(:resource) }
      subject { resource.document_builder }

      before do
        allow(Spotlight::Engine.config).to receive(:filter_resources_by_exhibit).and_return(true)
        allow(resource.document_builder).to receive(:to_solr).and_return(id: 'abc123')
        allow(resource_alt.document_builder).to receive(:to_solr).and_return(id: 'abc123')
        resource_alt.document_builder.documents_to_index.first
      end

      it 'has filter data for both exhibits' do
        result = resource.document_builder.documents_to_index.first
        expect(result).to include "spotlight_exhibit_slug_#{resource.exhibit.slug}_bsi"
        expect(result).to include "spotlight_exhibit_slug_#{resource_alt.exhibit.slug}_bsi"
      end
    end
  end
end
