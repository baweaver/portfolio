class Builders::SeriesBuilder < SiteBuilder
  def build
    helper "series_list", :series_list
    helper "post_series", :post_series
    helper "short_title", :short_title
  end

  def short_title(post, series_title)
    title = post.data.title || ""

    # Normalize curly quotes for matching
    norm_title = title.gsub(/[\u2018\u2019]/, "'")

    # Extract the topic from series title (e.g. "Eloquent Ruby" from "Let's Read: Eloquent Ruby")
    topic = series_title.sub(/\ALet'?s Read:?\s*/i, "").strip

    # Strip the series title and/or its components
    result = norm_title
      .sub(/\ALet['\u2019]?s Read[\s!]*[—–\-:]*\s*/i, "")
      .sub(/\A#{Regexp.escape(series_title)}\s*[—–\-:(]*\s*/i, "")
      .sub(/\A#{Regexp.escape(topic)}\s*[—–\-:(]*\s*/i, "")
      .sub(/\A[—–\-:]+\s*/, "")
      .sub(/\)\s*\z/, "")
      .strip

    # Normalize remaining separators to en-dash
    result = result.gsub(/\s+[-–—]\s+/, " – ")

    result.empty? ? title : result
  end

  def posts_for_series(series_id)
    site.collections.posts.resources
      .select { |p| p.data.series == series_id && p.data.date }
      .sort_by { |p| p.data.date }
  end

  def series_list
    series_defs = site.data.series || []
    series_defs.filter_map do |s|
      matching = posts_for_series(s["id"])
      next if matching.empty?

      latest = matching.last
      {
        "id" => s["id"],
        "title" => s["title"],
        "count" => matching.length,
        "latest_date" => latest.data.date,
        "latest_post" => latest,
        "posts" => matching
      }
    end.sort_by { |s| s["latest_date"] }.reverse
  end

  def post_series(resource)
    return nil unless resource.data.series

    series_defs = site.data.series || []
    s = series_defs.find { |d| d["id"] == resource.data.series }
    return nil unless s

    posts = posts_for_series(s["id"])
    idx = posts.index { |p| p.relative_url == resource.relative_url }
    {
      "id" => s["id"],
      "title" => s["title"],
      "posts" => posts,
      "current_index" => idx,
      "prev" => idx && idx > 0 ? posts[idx - 1] : nil,
      "next" => idx && idx < posts.length - 1 ? posts[idx + 1] : nil
    }
  end
end
