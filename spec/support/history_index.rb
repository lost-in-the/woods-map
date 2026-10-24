# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

module WoodsMap
  # A copy of the fixture index with retained generations whose commit
  # tables grow commit by commit, for the generation ledger and the picker:
  # of G generations, generation N's table lacks the fixture table's G - N
  # newest commits, so each later generation introduces one commit.
  module HistoryIndex
    module_function

    # @param generations [Integer]
    # @param table [Boolean] false publishes no git_commits.json anywhere
    # @return [String] the index root; the caller removes it
    def build(generations: 3, table: true)
      root = Dir.mktmpdir('woods-map-history')
      source = File.join(FIXTURE_INDEX, 'payloads', 'gen-1')
      full = JSON.parse(File.read(File.join(source, 'git_commits.json')))
      (1..generations).each do |number|
        payload = copy_payload(source, root, number)
        table_path = File.join(payload, 'git_commits.json')
        table ? File.write(table_path, JSON.generate(slice(full, generations - number))) : File.delete(table_path)
      end
      File.write(File.join(root, 'generation.json'),
                 JSON.generate('number' => generations, 'token' => "hist#{generations}",
                               'payload' => "payloads/gen-#{generations}"))
      root
    end

    # One payload, a copy of the fixture's with its own extraction date.
    def copy_payload(source, root, number)
      payload = File.join(root, 'payloads', "gen-#{number}")
      FileUtils.mkdir_p(payload)
      FileUtils.cp_r(Dir[File.join(source, '*')], payload)
      manifest_path = File.join(payload, 'manifest.json')
      manifest = JSON.parse(File.read(manifest_path)).merge('extracted_at' => "2026-10-#{10 + number}T00:00:00Z")
      File.write(manifest_path, JSON.generate(manifest))
      payload
    end

    # The table as it would have been `dropped` commits earlier.
    def slice(full, dropped)
      commits = full['commits'].drop(dropped)
      kept = commits.pluck('sha')
      paths = full['paths'].transform_values { |shas| shas & kept }.reject { |_, shas| shas.empty? }
      full.merge('head' => kept.first, 'commits' => commits, 'paths' => paths)
    end
  end
end
