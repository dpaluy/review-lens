module ReviewFixtureClassifier
  FixtureResult = Data.define(:path, :quality, :review_count, :blocked)

  module_function

  def classify(file_name)
    path = Rails.root.join("test/fixtures/files", file_name)
    html = File.read(path)
    blocked = html.match?(/captcha|blocked|verify you are human|unusual traffic/i)
    review_count = html.scan(/data-review-card=/).count

    FixtureResult.new(
      path: path.to_s,
      quality: quality_for(review_count, blocked),
      review_count: review_count,
      blocked: blocked
    )
  end

  def quality_for(review_count, blocked)
    return :blocked if blocked
    return :viable if review_count >= 20

    :thin
  end
end
