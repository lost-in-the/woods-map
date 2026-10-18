# frozen_string_literal: true

require 'digest'
require 'pathname'

module WoodsMap
  # The engine's own static files, served by {WoodsMap::AssetsController}
  # under a content-hash prefix: `/woods/assets/<digest>/<logical path>`.
  #
  # There is no asset pipeline and no build step (NFR-1). The roots are read
  # straight from the gem, a digest is the first sixteen hex characters of the
  # file's SHA-256, and a URL naming a stale digest is a 404. That is what lets
  # every response be cached as immutable: a gem upgrade changes every URL
  # instead of serving a new body under an old one.
  module Assets
    # Directories a logical path may resolve under, in lookup order.
    ROOTS = [
      Pathname.new(File.expand_path('../../app/javascript', __dir__)),
      Pathname.new(File.expand_path('../../app/assets/stylesheets', __dir__)),
      Pathname.new(File.expand_path('../../vendor/javascript', __dir__)),
      Pathname.new(File.expand_path('../../vendor/fonts', __dir__))
    ].freeze

    # Extension => Content-Type the assets route answers with.
    CONTENT_TYPES = {
      '.js' => 'text/javascript; charset=utf-8',
      '.mjs' => 'text/javascript; charset=utf-8',
      '.css' => 'text/css; charset=utf-8',
      '.map' => 'application/json; charset=utf-8',
      '.woff2' => 'font/woff2'
    }.freeze

    # The token sheet (D-10): the one stylesheet every view is styled by.
    TOKENS = 'woods_map/tokens.css'

    # Engine-only rules the token sheet does not carry; see the file's header.
    MAP = 'woods_map/map.css'

    module_function

    # Resolve a logical path to a file under one of the roots.
    #
    # @param logical_path [String]
    # @return [Pathname, nil] nil when the path escapes the roots or is absent
    def resolve(logical_path)
      path = logical_path.to_s
      return nil if path.empty? || path.include?("\0")

      ROOTS.each do |root|
        candidate = root.join(path).cleanpath
        next unless candidate.to_s.start_with?("#{root}/") && candidate.file?

        return candidate
      end
      nil
    end

    # @param logical_path [String]
    # @return [String, nil] first 16 hex chars of the file's SHA-256, or nil
    def digest(logical_path)
      file = resolve(logical_path)
      file && Digest::SHA256.file(file.to_s).hexdigest[0, 16]
    end

    # @param file [Pathname]
    # @return [String] the Content-Type for the file's extension
    def content_type(file)
      CONTENT_TYPES.fetch(file.extname, 'application/octet-stream')
    end
  end
end
