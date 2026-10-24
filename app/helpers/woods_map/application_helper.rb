# frozen_string_literal: true

module WoodsMap
  # View helpers shared by every page: engine-served asset URLs, the
  # relative-date shorthand (D-15) and the short SHA.
  module ApplicationHelper
    # Thresholds of git's relative dates, in days, below which the next
    # smaller unit is used (`git log --date=relative`).
    DAYS_AS_DAYS = 14
    DAYS_AS_WEEKS = 70
    DAYS_AS_MONTHS = 365
    YEARS_WITH_MONTHS = 5

    # @param logical_path [String] a path under {WoodsMap::Assets::ROOTS}
    # @return [String] the content-hashed URL the assets route serves it at
    # @raise [ArgumentError] when the file is not part of the engine
    def woods_map_asset_path(logical_path)
      raise ArgumentError, "Not an engine asset: #{logical_path}" unless WoodsMap::Assets.resolve(logical_path)

      woods_map.engine_asset_path(digest: WoodsMap::Assets.digest, path: logical_path)
    end

    # The `<link>` tags for the fonts, the token sheet and the engine sheet,
    # with the regular weight of each face preloaded (D-12).
    #
    # @return [ActiveSupport::SafeBuffer]
    def woods_map_stylesheet_tags
      preloads = WoodsMap::Assets::PRELOADED_FONTS.map do |font|
        tag.link(rel: 'preload', as: 'font', type: 'font/woff2', href: woods_map_asset_path(font),
                 crossorigin: 'anonymous')
      end
      sheets = [WoodsMap::Assets::FONTS, WoodsMap::Assets::TOKENS, WoodsMap::Assets::MAP].map do |logical_path|
        tag.link(rel: 'stylesheet', href: woods_map_asset_path(logical_path))
      end
      safe_join(preloads + sheets, "\n")
    end

    # The focus URL of this page (E-6): its absolute address with the query
    # it was opened with, less any `token` (D-4 exchanges it for a cookie, and
    # a shared link must never carry it).
    #
    # @return [String]
    def focus_url
      query = request.query_parameters.except('token')
      "#{request.base_url}#{raw_request_path}#{"?#{query.to_query}" if query.any?}"
    end

    # A relative date in git's shorthand with the long form in the tooltip
    # (D-15): `<abbr class="date" title="3 days ago, 2026-10-13">3d</abbr>`.
    #
    # @param value [Time, String, nil] a time or an ISO 8601 string
    # @param now [Time] the reference time
    # @return [ActiveSupport::SafeBuffer, String] the abbr, or `—` when unknown
    def date_abbr(value, now: Time.now.utc)
      time = parse_time(value)
      return tag.span('—', class: 'dim') unless time

      short, long = relative_date(time, now)
      tag.abbr(short, class: 'date', title: long)
    end

    # @param sha [String, nil]
    # @return [String] the first seven characters, or `unknown`
    def short_sha(sha)
      sha.to_s.empty? || sha == 'unknown' ? 'unknown' : sha.to_s[0, 7]
    end

    # git's relative-date buckets as [shorthand, long form].
    #
    # @param time [Time]
    # @param now [Time]
    # @return [Array(String, String)]
    def relative_date(time, now)
      seconds = (now - time).to_i
      return ['now', "just now, #{time.strftime('%Y-%m-%d %H:%M')}"] if seconds < 60

      minutes = seconds / 60
      return ["#{minutes}m", "#{plural(minutes, 'minute')} ago, #{time.strftime('%Y-%m-%d %H:%M')}"] if minutes < 60

      hours = minutes / 60
      return ["#{hours}h", "#{plural(hours, 'hour')} ago, #{time.strftime('%Y-%m-%d %H:%M')}"] if hours < 24

      relative_days(hours / 24, time)
    end

    private

    def relative_days(days, time)
      date = time.strftime('%Y-%m-%d')
      count, unit, short = days_bucket(days)
      return relative_years(days, date) if unit.nil?

      ["#{count}#{short}", "#{plural(count, unit)} ago, #{date}"]
    end

    # @return [Array(Integer, String, String), Array(nil)] count, unit, shorthand suffix
    def days_bucket(days)
      if days < DAYS_AS_DAYS then [days, 'day', 'd']
      elsif days < DAYS_AS_WEEKS then [(days + 3) / 7, 'week', 'w']
      elsif days < DAYS_AS_MONTHS then [(days + 15) / 30, 'month', 'mo']
      else [nil]
      end
    end

    def relative_years(days, date)
      years = days / 365
      months = ((days % 365) + 15) / 30
      if years < YEARS_WITH_MONTHS && months.positive?
        ["#{years}y #{months}mo", "#{plural(years, 'year')}, #{plural(months, 'month')} ago, #{date}"]
      else
        ["#{years}y", "#{plural(years, 'year')} ago, #{date}"]
      end
    end

    def plural(count, word)
      "#{count} #{word}#{'s' unless count == 1}"
    end

    def parse_time(value)
      case value
      when Time then value.utc
      when String then Time.iso8601(value).utc
      end
    rescue ArgumentError
      nil
    end
  end
end
