# frozen_string_literal: true

# Every page's ids are unique: an id names one anchor, one label for
# aria-labelledby and one list for aria-controls. The end-to-end sweep found
# the History tab giving a section and its heading the same id, and the
# guidelines repeating the palette's.
RSpec.describe 'Ids on every page', type: :request do
  %w[
    /woods /woods/units /woods/units/model/User /woods/units/model/User/schema /woods/units/model/User/lifecycle
    /woods/units/model/User/graph /woods/units/model/User/history /woods/units/controller/UsersController/routes
    /woods/units/controller/UsersController/passage /woods/units/route/GET%20/users /woods/files/app/models/user.rb
    /woods/search?q=User /woods/graph /woods/graph?centre=User&type=model /woods/erd /woods/impact
    /woods/impact?focus=User /woods/history /woods/landscape /woods/guidelines
  ].each do |path|
    it "are unique on #{path}" do
      get path
      expect(response).to have_http_status(:ok)
      ids = html_response_document.css('[id]').pluck('id')
      expect(ids.tally.select { |_, count| count > 1 }.keys).to eq([])
    end
  end
end
