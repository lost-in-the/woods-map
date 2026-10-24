# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # The fixture index with the precomputed flow family a Woods with W-13
  # writes (woods#805): `flows/flow_index.json`, one flow document and the
  # typed inverse `flows/by_unit.json`. Built in a temporary directory so the
  # shared fixture stays as the older Woods wrote it.
  module FlowIndex
    ENTRY = 'MicropostsController#create'

    DOCUMENT = {
      'entry_point' => ENTRY, 'route' => { 'verb' => 'POST', 'path' => '/microposts' }, 'max_depth' => 3,
      'generated_at' => '2026-10-20T12:00:00+00:00',
      'steps' => [
        { 'unit' => ENTRY, 'type' => 'controller', 'file_path' => 'app/controllers/microposts_controller.rb',
          'operations' => [{ 'type' => 'call', 'method' => 'build', 'target' => 'current_user.microposts',
                             'line' => 5 },
                           { 'type' => 'call', 'method' => 'save', 'target' => '@micropost', 'line' => 6 }] },
        { 'unit' => 'Micropost', 'type' => 'model', 'file_path' => 'app/models/micropost.rb', 'operations' => [] },
        { 'unit' => 'User', 'type' => 'model', 'file_path' => 'app/models/user.rb', 'operations' => [] },
        { 'unit' => 'ApplicationJob', 'type' => 'job', 'file_path' => 'app/jobs/application_job.rb',
          'operations' => [{ 'type' => 'call', 'method' => 'perform_later', 'target' => nil, 'line' => nil }] }
      ]
    }.freeze

    INVERSE = {
      'MicropostsController' => { 'controller' => [ENTRY] },
      'Micropost' => { 'model' => [ENTRY] },
      'User' => { 'model' => [ENTRY] },
      'ApplicationJob' => { 'job' => [ENTRY] }
    }.freeze

    module_function

    # @return [String] the index root, written once per process and removed at exit
    def path
      @path ||= begin
        dir = Dir.mktmpdir('woods-map-flows')
        at_exit { FileUtils.remove_entry(dir) if File.directory?(dir) }
        FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), dir)
        flows = File.join(dir, 'payloads', 'gen-1', 'flows')
        FileUtils.rm_rf(flows)
        FileUtils.mkdir_p(flows)
        File.write(File.join(flows, 'flow_index.json'),
                   JSON.generate(ENTRY => 'flows/MicropostsController_create.json'))
        File.write(File.join(flows, 'MicropostsController_create.json'), JSON.generate(DOCUMENT))
        File.write(File.join(flows, 'by_unit.json'), JSON.generate(INVERSE))
        dir
      end
    end

    # @return [String] the fixture index with no flow family, as a generation
    #   extracted with `precompute_flows` off is published
    def bare_path
      @bare_path ||= begin
        dir = Dir.mktmpdir('woods-map-no-flows')
        at_exit { FileUtils.remove_entry(dir) if File.directory?(dir) }
        FileUtils.cp_r(File.join(FIXTURE_INDEX, '.'), dir)
        FileUtils.rm_rf(File.join(dir, 'payloads', 'gen-1', 'flows'))
        dir
      end
    end

    # @return [Boolean] whether the Woods in the bundle reads the flow family (W-13)
    def readers?
      Woods::PublishedIndex.method_defined?(:flow_entry_points)
    end
  end
end
