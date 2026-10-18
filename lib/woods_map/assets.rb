# frozen_string_literal: true

require 'digest'
require 'pathname'

module WoodsMap
  # The engine's own static files, served by {WoodsMap::AssetsController}
  # under a content-hash prefix: `/woods/assets/<digest>/<logical path>`.
  #
  # There is no asset pipeline and no build step (NFR-1). The roots are read
  # straight from the gem and one digest covers the whole set: the SHA-256 of
  # every file's path and bytes. A URL naming a stale digest is a 404, which is
  # what lets every response be cached as immutable, and one digest for the
  # set is what lets a stylesheet or a module reach its neighbours with a
  # relative URL (`fonts.css` finds the WOFF2 files beside it).
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

    # Extensions the route serves; anything else under the roots is a 404.
    SERVED = CONTENT_TYPES.keys.freeze

    # The token sheet (D-10): the one stylesheet every view is styled by.
    TOKENS = 'woods_map/tokens.css'

    # Engine-only rules the token sheet does not carry; see the file's header.
    MAP = 'woods_map/map.css'

    # The `@font-face` rules for the vendored Inter and Fira Code (D-12).
    FONTS = 'woods_map/fonts.css'

    # Preloaded from the layout: the regular weight of each face.
    PRELOADED_FONTS = %w[inter/inter-latin-400-normal.woff2 fira-code/FiraCode-Regular.woff2].freeze

    @digest_mutex = Mutex.new

    class << self
      # Resolve a logical path to a file under one of the roots.
      #
      # @param logical_path [String]
      # @return [Pathname, nil] nil when the path escapes the roots, has an
      #   extension the route does not serve, or is absent
      def resolve(logical_path)
        path = logical_path.to_s
        return nil if path.empty? || path.include?("\0") || SERVED.exclude?(File.extname(path))

        ROOTS.each do |root|
          candidate = root.join(path).cleanpath
          next unless candidate.to_s.start_with?("#{root}/") && candidate.file?

          return candidate
        end
        nil
      end

      # Every served file as logical path => absolute path, sorted.
      #
      # @return [Hash{String => Pathname}]
      def files
        ROOTS.each_with_object({}) do |root, map|
          next unless root.directory?

          Dir.glob('**/*', base: root.to_s).sort.each do |relative|
            file = root.join(relative)
            next unless file.file? && SERVED.include?(file.extname) && !map.key?(relative)

            map[relative] = file
          end
        end
      end

      # The digest of the whole set: 16 hex characters of a SHA-256 over every
      # file's logical path and bytes. Memoized for the life of the process;
      # the gem's files do not change underneath a running host.
      #
      # @return [String]
      def digest
        @digest_mutex.synchronize { @digest ||= compute_digest }
      end

      # Forget the memoized digest (specs that rewrite a vendored file).
      #
      # @return [void]
      def reset!
        @digest_mutex.synchronize { @digest = nil }
      end

      # @param file [Pathname]
      # @return [String] the Content-Type for the file's extension
      def content_type(file)
        CONTENT_TYPES.fetch(file.extname, 'application/octet-stream')
      end

      private

      def compute_digest
        sha = Digest::SHA256.new
        files.each do |relative, file|
          sha << relative << "\0"
          sha << File.binread(file.to_s) << "\0"
        end
        sha.hexdigest[0, 16]
      end
    end
  end
end
