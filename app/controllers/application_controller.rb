class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes in importmap will invalidate etag for HTML responses.
  stale_when_importmap_changes
end
