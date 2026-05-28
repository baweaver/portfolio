class Shared::RelatedPosts < Bridgetown::Component
  def initialize(resource:, site:, limit: 3)
    @resource = resource
    @posts = []
    return unless resource.data.tags&.any?

    @tags = resource.data.tags.map(&:downcase)

    @posts = site.collections.posts.resources
      .reject { |p| p.relative_url == resource.relative_url }
      .select { |p| p.data.tags&.any? }
      .map { |p| { post: p, score: relevance_score(p) } }
      .select { |h| h[:score] > 1 }
      .sort_by { |h| -h[:score] }
      .first(limit)
      .map { |h| h[:post] }
  end

  def render?
    @posts.any?
  end

  def posts = @posts

  private

  def relevance_score(post)
    tag_overlap = (post.data.tags.map(&:downcase) & @tags).size
    days_old = (Date.today - post.data.date.to_date).to_i
    recency = 1.0 / (1 + days_old / 365.0)

    tag_overlap * 2 + recency
  end
end
