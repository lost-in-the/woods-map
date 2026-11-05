# frozen_string_literal: true

require_relative 'support/browser_page'

RSpec.describe 'Table value scroll guidance in Chromium', type: :request do
  include WoodsMap::BrowserPage

  before do
    skip 'Set WOODS_MAP_BROWSER to run the Chromium regression' unless ENV['WOODS_MAP_BROWSER']
    get '/woods/erd'
  end

  it 'keeps conditional guidance visible before the cliff controller runs' do
    html = response.body.gsub('data-controller="cliff"', '')
    report = run_page(html, width: 390, runner: <<~JS)
      const value = document.querySelector('.table-value')
      const hint = value.nextElementSibling
      report({ visible: getComputedStyle(hint).display !== 'none',
               conditional: hint.textContent.includes('if clipped'),
               named: !!value.getAttribute('aria-label'), focusable: value.tabIndex === 0 })
    JS
    expect(report).to eq('visible' => true, 'conditional' => true, 'named' => true, 'focusable' => true)
  end

  it 'announces scrolling only while a value overflows, as content changes' do
    report = run_page(response.body, width: 390, runner: guidance_runner)
    expect(report).to eq([{ 'scroll' => true, 'hint' => true, 'focusable' => true },
                          { 'scroll' => false, 'hint' => false, 'focusable' => false },
                          { 'scroll' => true, 'hint' => true, 'focusable' => true }])
  end

  # @return [String] measure guidance across overflowing and fitting content
  def guidance_runner
    <<~JS
      const value = document.querySelector('.table-value'), link = value.querySelector('a')
      const controller = application.getControllerForElementAndIdentifier(value, 'cliff')
      const states = []
      for (const text of ['LongPublishedIdentifier'.repeat(10), 'x', 'LongPublishedIdentifier'.repeat(10)]) {
        link.textContent = text
        controller.update()
        states.push({ scroll: value.getAttribute('aria-label').includes('scroll horizontally'),
                      hint: getComputedStyle(value.nextElementSibling).display !== 'none',
                      focusable: value.hasAttribute('tabindex') })
      }
      report(states)
    JS
  end
end
