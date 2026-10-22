# frozen_string_literal: true

RSpec.describe 'Accessible diagram sources', type: :request do
  it 'gives every Schema section label a target that exists in the page' do
    get '/woods/units/model/User/schema'
    document = parsed_document
    missing = document.css('[aria-labelledby]').flat_map do |element|
      element['aria-labelledby'].split.reject { |id| document.at_css("##{id}") }
    end
    expect(missing).to eq([])
  end

  it 'names Schema and Lifecycle Mermaid sources as scrollable regions' do
    %w[schema lifecycle].each do |tab|
      get "/woods/units/model/User/#{tab}"
      source = parsed_document.at_css('pre[role="region"][aria-label="Mermaid source"]')
      expect(source).not_to be_nil, "expected a named Mermaid region on #{tab}"
    end
  end

  def parsed_document
    body = response.parsed_body
    body.is_a?(String) ? Nokogiri::HTML(body) : body
  end
end
