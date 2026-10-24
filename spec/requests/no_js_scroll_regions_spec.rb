# frozen_string_literal: true

# Without JavaScript the cliff controller never runs, so a region that
# scrolls sideways at 390 (a wide table, the code view, the Mermaid source,
# the history timeline) must already be reachable from the keyboard in the
# server-rendered HTML (axe scrollable-region-focusable; the M1 criterion
# "works with JavaScript disabled"). The controller still drops the tab stop
# where nothing overflows once it runs.
RSpec.describe 'Scroll regions without JavaScript', type: :request do
  let(:doc) { html_response_document }

  def regions
    doc.css('.tblwrap, pre.cmd, .cvwrap, .tl')
  end

  %w[/woods/units/model/User/schema /woods/units/model/User /woods/units/model/User/lifecycle
     /woods/units/controller/UsersController/passage?action_name=edit].each do |path|
    it "renders every scroll region on #{path} focusable, as a named region" do
      get path
      expect(response).to have_http_status(:ok)
      expect(regions).not_to be_empty
      regions.each do |region|
        expect(region.to_h).to include('tabindex' => '0', 'role' => 'region'), region.to_s[0, 160]
        expect(region['aria-label'].to_s).not_to be_empty, region.to_s[0, 160]
      end
    end
  end
end
