# frozen_string_literal: true

require_relative '../support/code_navigation_index'

RSpec.describe 'Code navigation from reference spans and method tables', type: :request do
  include CodeNavigationIndex

  def code(path = '/woods/units/model/Post?lens=written')
    get path
    follow_redirect! if response.redirect?
    response.parsed_body
  end

  it 'links a method call to the line that defines it, and a callback to its own method' do
    page = code
    job = page.at_css('.cv .src a[data-target="NotifyJob"]')
    expect([job['href'], job['data-method'], job['aria-label']])
      .to eq(['/woods/units/job/NotifyJob#L2', 'deliver_all',
              'NotifyJob.deliver_all (job, line 2), verified constant reference'])
    callback = page.at_css('.cv .src a[data-kind="callback_method"]')
    expect([callback['href'], callback.text]).to eq(['/woods/units/model/Post#L13', ':set_slug'])
    expect(page.at_css('.cv .src a[data-kind="association"]')['href']).to eq('/woods/units/model/Author')
  end

  it 'marks a static reference as such' do
    link = code.at_css('.cv .src a[data-target="Helper"]')
    expect(link['class']).to eq('const static')
    expect(link['aria-label']).to eq('Helper.call (poro), static reference, not verified at runtime')
  end

  it 'turns an ambiguous reference into a button for a popover listing every candidate with its path' do
    page = code
    button = page.at_css('.cv .src button.amb')
    expect([button.text, button['aria-haspopup'], button['aria-expanded']]).to eq(%w[Notifier dialog false])
    popover = page.at_css("##{button['aria-controls']}")
    expect([popover['role'], popover['aria-label'],
            popover.key?('hidden')]).to eq(['dialog', 'Candidates for Notifier', true])
    expect(popover.css('li').map { |item| item.text.squish })
      .to eq(['Admin::Notifier service app/services/admin/notifier.rb', 'Notifier lib lib/notifier.rb'])
    expect(popover.css('a').pluck('href'))
      .to eq(['/woods/units/service/Admin::Notifier', '/woods/units/lib/Notifier'])
  end

  it 'outlines methods by owner from the method table, each linked to its line' do
    rail = code.css('nav.rail li')
    items = rail.map { |item| [item.at_css('a')&.text, item.at_css('a')&.[]('href'), item.at_css('.own')&.text] }
    expect(items).to include(['self.publish_all', '#L5', '1 caller'], ['set_slug', '#L13', 'private'],
                             ['tag_list', '/woods/units/concern/Taggable#L3', nil])
  end

  it 'lists the callers of a unit by method, with the margin saying where a definition is called from' do
    page = code('/woods/units/job/NotifyJob?lens=written')
    rows = page.css('table[aria-label="Callers of NotifyJob"] tbody tr').map do |row|
      row.css('td').map do |c|
        c.text.squish
      end
    end
    expect(rows).to eq([['.deliver_all', 'Comment', '4', 'verified span'],
                        ['.deliver_all', 'Post', '6', 'verified span']])
    expect(page.at_css('table[aria-label="Callers of NotifyJob"] a')['href']).to eq('/woods/units/model/Comment#L4')
    expect(page.at_css('#L2 .mg').text.squish).to start_with('called from 2: Comment, Post')
  end

  it 'says when no published reference names the unit' do
    expect(code('/woods/units/model/Author').at_css('#callers-h').parent.parent.text)
      .to include('No published reference names Author in this generation.')
  end
end
