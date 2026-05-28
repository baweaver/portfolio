class Shared::PathNav < Bridgetown::Component
  def initialize(resource:, site:)
    @resource = resource
    @path_data = site.data.learning_paths&.find { |lp| lp["posts"]&.include?(resource.relative_url) }
    return unless @path_data

    posts = site.collections.posts.resources
    path_posts = @path_data["posts"]
    @index = path_posts.index(resource.relative_url)
    @total = path_posts.length

    prev_url = @index > 0 ? path_posts[@index - 1] : nil
    next_url = path_posts[@index + 1]

    @prev_post = prev_url && posts.find { |p| p.relative_url == prev_url }
    @next_post = next_url && posts.find { |p| p.relative_url == next_url }
  end

  def render?
    !!@path_data
  end

  def path_title = @path_data["title"]
  def position = @index + 1
  def total = @total
  def prev_post = @prev_post
  def next_post = @next_post
end
