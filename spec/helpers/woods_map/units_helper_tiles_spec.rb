# frozen_string_literal: true

RSpec.describe WoodsMap::UnitsHelper, type: :helper do
  it 'offers a line break after each namespace and path separator in a tile value' do
    html = helper.tile_value('Admin::Newsletters::CampaignsController in app/controllers/admin')
    expect(html).to eq('Admin::<wbr>Newsletters::<wbr>CampaignsController in app/<wbr>controllers/<wbr>admin')
  end

  it 'escapes a tile value that carries markup' do
    expect(helper.tile_value('<b>A::B</b>')).to eq('&lt;b&gt;A::<wbr>B&lt;/<wbr>b&gt;')
  end

  it 'offers the same breaks inside a linked tile name' do
    allow(helper).to receive(:current_repository).and_return(nil)
    html = helper.tile_value(links: [['Admin::Newsletters::CampaignsController', 'controller']])
    expect(html).to include('Admin::<wbr>Newsletters::<wbr>CampaignsController')
  end
end
